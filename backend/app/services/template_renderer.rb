# Renders a template into a final, send-ready subject and body for a given set
# of Liquid variables. Centralizes the markdown -> HTML transformation and the
# layout wrapping so every send path produces identical output.
#
# Previously this logic lived only inline in MessagesController#trigger, so the
# drip path (DripStepSender) shipped raw markdown: paragraph breaks were never
# turned into <p> blocks, which collapsed into one run-on paragraph both in the
# delivered email and in the message viewer's "Rendered Content" iframe.
class TemplateRenderer
  # body = the send-ready body (layout applied); content = the body after Liquid
  # and markdown transformers but BEFORE the layout.
  Result = Struct.new(:subject, :body, :content, :preview, keyword_init: true)

  # What previews render for unsubscribe_url. A customized copy of a preview
  # comes back to POST /messages with it, which swaps in the real link.
  PREVIEW_UNSUBSCRIBE_URL = "#unsubscribe".freeze

  # Loop/local names Liquid provides itself; never "missing".
  BUILTIN_VARIABLES = %w[forloop tablerowloop].freeze

  def self.call(template:, variables:)
    new(template: template, variables: variables).call
  end

  # Wraps already-rendered HTML content in a layout. Shared by template sends
  # and one-off messages that name a layout directly.
  def self.wrap_in_layout(layout, content:, preview:, variables: {})
    Liquid::Template.parse(layout.body).render(
      variables.merge("content" => content, "preview" => preview)
    )
  end

  def initialize(template:, variables:)
    @template = template
    @variables = variables
  end

  def call
    Result.new(subject: rendered_subject, body: rendered_body, content: rendered_content, preview: rendered_preview)
  end

  # Top-level Liquid variables used in the subject, body or preview that the
  # caller didn't supply (missing ones render empty). Names defined inside the
  # template itself (assign/capture/for) don't count.
  def missing_variables
    used = []
    locals = BUILTIN_VARIABLES.dup
    [template.subject, template.body, template.preview].compact_blank.each do |source|
      root = Liquid::Template.parse(source).root
      Liquid::ParseTreeVisitor.for(root)
        .add_callback_for(Liquid::VariableLookup) { |node| used << node.name if node.name.is_a?(String) }
        .visit
      locals.concat(self.class.local_variables(root))
    end
    used.uniq - locals - variables.keys.map(&:to_s)
  end

  # Names a parsed Liquid template defines itself (assign/capture/for), which a
  # caller never has to supply.
  def self.local_variables(root)
    locals = []
    Liquid::ParseTreeVisitor.for(root)
      .add_callback_for(Liquid::Assign) { |node| locals << node.to }
      .add_callback_for(Liquid::Capture) { |node| locals << node.instance_variable_get(:@to) }
      .add_callback_for(Liquid::For, Liquid::TableRow) { |node| locals << node.variable_name }
      .visit
    locals
  end

  private

  attr_reader :template, :variables

  def rendered_subject
    return template.subject if template.subject.blank?

    Liquid::Template.parse(template.subject).render(variables)
  end

  def rendered_content
    @rendered_content ||= begin
      body = Liquid::Template.parse(template.body.to_s).render(variables)

      # Transform markdown to HTML using layout transformers (skip for push — plain text only)
      if template.body_format == "markdown" && template.channel != "push"
        transformers = template.layout&.transformers || {}
        body = MarkdownTransformer.new(transformers).render(body)
      end

      body
    end
  end

  def rendered_body
    return rendered_content unless template.layout.present? && template.channel != "push"

    self.class.wrap_in_layout(template.layout, content: rendered_content, preview: rendered_preview, variables: variables)
  end

  def rendered_preview
    @rendered_preview ||= template.preview.blank? ? "" : Liquid::Template.parse(template.preview).render(variables)
  end
end

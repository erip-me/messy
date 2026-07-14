# Renders a template into a final, send-ready subject and body for a given set
# of Liquid variables. Centralizes the markdown -> HTML transformation and the
# layout wrapping so every send path produces identical output.
#
# Previously this logic lived only inline in MessagesController#trigger, so the
# drip path (DripStepSender) shipped raw markdown: paragraph breaks were never
# turned into <p> blocks, which collapsed into one run-on paragraph both in the
# delivered email and in the message viewer's "Rendered Content" iframe.
class TemplateRenderer
  Result = Struct.new(:subject, :body, keyword_init: true)

  def self.call(template:, variables:)
    new(template: template, variables: variables).call
  end

  def initialize(template:, variables:)
    @template = template
    @variables = variables
  end

  def call
    Result.new(subject: rendered_subject, body: rendered_body)
  end

  private

  attr_reader :template, :variables

  def rendered_subject
    return template.subject if template.subject.blank?

    Liquid::Template.parse(template.subject).render(variables)
  end

  def rendered_body
    body = Liquid::Template.parse(template.body.to_s).render(variables)

    # Transform markdown to HTML using layout transformers (skip for push — plain text only)
    if template.body_format == "markdown" && template.channel != "push"
      transformers = template.layout&.transformers || {}
      body = MarkdownTransformer.new(transformers).render(body)
    end

    if template.layout.present? && template.channel != "push"
      body = Liquid::Template.parse(template.layout.body).render(
        variables.merge("content" => body, "preview" => rendered_preview)
      )
    end

    body
  end

  def rendered_preview
    return "" if template.preview.blank?

    Liquid::Template.parse(template.preview).render(variables)
  end
end

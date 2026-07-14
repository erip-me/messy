# Transforms markdown content into email-ready HTML using layout-defined
# transformer rules.  Mirrors the frontend logic in markdown-transformer.ts.
#
# Each transformer rule is an HTML template string with placeholders like
# {{text}}, {{href}}, {{src}}, {{alt}}, {{level}}.
class MarkdownTransformer
  DEFAULTS = {
    "heading"   => '<h{{level}}>{{text}}</h{{level}}>',
    "paragraph" => '<p>{{text}}</p>',
    "link"      => '<a href="{{href}}">{{text}}</a>',
    "image"     => '<img src="{{src}}" alt="{{alt}}" />',
    "strong"    => '<strong>{{text}}</strong>',
    "em"        => '<em>{{text}}</em>',
    "list"      => '<tr><td style="padding: 8px 40px;"><table cellpadding="0" cellspacing="0" border="0" width="100%" role="presentation">{{body}}</table></td></tr>',
    "listitem"  => '<tr><td style="padding: 4px 0; font-size: 16px; line-height: 24px;">• {{text}}</td></tr>',
    "blockquote"=> '<blockquote>{{text}}</blockquote>',
    "hr"        => '<hr />',
    "codespan"  => '<code>{{text}}</code>'
  }.freeze

  def initialize(transformers = {})
    @transformers = (transformers || {}).stringify_keys
  end

  def render(markdown)
    renderer = TransformerRenderer.new(@transformers)
    parser = Redcarpet::Markdown.new(renderer,
      no_intra_emphasis: true,
      tables: true,
      fenced_code_blocks: true,
      autolink: true,
      strikethrough: true
    )
    parser.render(markdown.to_s)
  end

  # Custom Redcarpet renderer that applies transformer templates.
  class TransformerRenderer < Redcarpet::Render::HTML
    def initialize(transformers)
      super()
      @transformers = transformers
    end

    def header(text, level)
      apply("heading", { "text" => text, "level" => level.to_s }) ||
        "<h#{level}>#{text}</h#{level}>"
    end

    def paragraph(text)
      apply("paragraph", { "text" => text }) ||
        "<p>#{text}</p>"
    end

    def link(link, _title, content)
      apply("link", { "href" => link.to_s, "text" => content.to_s }) ||
        "<a href=\"#{link}\">#{content}</a>"
    end

    def image(link, _title, alt_text)
      apply("image", { "src" => link.to_s, "alt" => alt_text.to_s }) ||
        "<img src=\"#{link}\" alt=\"#{alt_text}\" />"
    end

    def double_emphasis(text)
      apply("strong", { "text" => text }) ||
        "<strong>#{text}</strong>"
    end

    def emphasis(text)
      apply("em", { "text" => text }) ||
        "<em>#{text}</em>"
    end

    def list(content, list_type)
      template = @transformers["list"].presence || DEFAULTS["list"]
      apply_with_template(template, { "body" => content, "text" => content, "ordered" => (list_type == :ordered).to_s })
    end

    def list_item(text, list_type)
      template = @transformers["listitem"].presence || DEFAULTS["listitem"]
      apply_with_template(template, { "text" => text, "body" => text })
    end

    def block_quote(text)
      apply("blockquote", { "text" => text }) ||
        "<blockquote>#{text}</blockquote>"
    end

    def hrule
      @transformers["hr"].presence || "<hr />"
    end

    def codespan(code)
      apply("codespan", { "text" => code }) ||
        "<code>#{code}</code>"
    end

    private

    def apply(key, vars)
      template = @transformers[key]
      return nil if template.blank?

      apply_with_template(template, vars)
    end

    def apply_with_template(template, vars)
      result = template.dup
      vars.each { |k, v| result.gsub!("{{#{k}}}", v) }
      result
    end
  end
end

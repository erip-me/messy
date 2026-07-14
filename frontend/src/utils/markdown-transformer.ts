import { marked, type Tokens } from "marked";
import { EMAIL_COLORS } from "@/lib/email-colors";

/**
 * Transformer rules defined on a layout.
 * Each key is a markdown element type, value is an HTML template string
 * with placeholders like {{text}}, {{href}}, {{src}}, {{alt}}, {{level}}.
 */
export interface TransformerRules {
  heading?: string;
  paragraph?: string;
  link?: string;
  image?: string;
  strong?: string;
  em?: string;
  list?: string;
  listitem?: string;
  blockquote?: string;
  hr?: string;
  codespan?: string;
}

export const TRANSFORMER_ELEMENT_TYPES: {
  key: keyof TransformerRules;
  label: string;
  description: string;
  placeholders: string[];
  defaultTemplate: string;
  exampleMarkdown: string;
  hint?: string;
}[] = [
  {
    key: "heading",
    label: "Heading",
    description: "# Heading text",
    placeholders: ["{{text}}", "{{level}}"],
    defaultTemplate: `<tr>
  <td style="padding: 10px 40px;">
    <h1 style="margin: 0; font-size: 28px; line-height: 36px; font-weight: 700; text-align: center;">
      {{text}}
    </h1>
  </td>
</tr>`,
    exampleMarkdown: "# Hello World",
  },
  {
    key: "paragraph",
    label: "Paragraph",
    description: "Regular text",
    placeholders: ["{{text}}"],
    defaultTemplate: `<tr>
  <td style="padding: 8px 40px;">
    <p style="margin: 0; font-size: 16px; line-height: 24px;">
      {{text}}
    </p>
  </td>
</tr>`,
    exampleMarkdown: "This is a paragraph of text.",
  },
  {
    key: "link",
    label: "Link / CTA Button",
    description: "[Link Text](url)",
    placeholders: ["{{text}}", "{{href}}"],
    defaultTemplate: `<a href="{{href}}" target="_blank" style="color: ${EMAIL_COLORS.link}; text-decoration: underline;">{{text}}</a>`,
    exampleMarkdown: "[Click here](https://example.com)",
  },
  {
    key: "image",
    label: "Image",
    description: "![alt](url)",
    placeholders: ["{{src}}", "{{alt}}"],
    defaultTemplate: `<tr>
  <td style="padding: 10px 40px; text-align: center;">
    <img src="{{src}}" alt="{{alt}}" style="max-width: 100%; height: auto; border-radius: 8px;" />
  </td>
</tr>`,
    exampleMarkdown: "![Logo](https://example.com/logo.png)",
  },
  {
    key: "strong",
    label: "Bold",
    description: "**bold text**",
    placeholders: ["{{text}}"],
    defaultTemplate: `<strong style="font-weight: 700;">{{text}}</strong>`,
    exampleMarkdown: "**bold text**",
  },
  {
    key: "em",
    label: "Italic",
    description: "*italic text*",
    placeholders: ["{{text}}"],
    defaultTemplate: `<em>{{text}}</em>`,
    exampleMarkdown: "*italic text*",
  },
  {
    key: "list",
    label: "List",
    description: "- item or 1. item",
    placeholders: ["{{body}}", "{{text}}", "{{ordered}}"],
    hint: "Use {{body}} or {{text}} where the rendered list items should be inserted. {{ordered}} is \"true\" for numbered lists.",
    defaultTemplate: `<tr>
  <td style="padding: 8px 40px;">
    <table cellpadding="0" cellspacing="0" border="0" width="100%" role="presentation">
      {{body}}
    </table>
  </td>
</tr>`,
    exampleMarkdown: "- First item\n- Second item\n- Third item",
  },
  {
    key: "listitem",
    label: "List Item",
    description: "Individual list entry",
    placeholders: ["{{text}}", "{{body}}"],
    hint: "Use {{text}} or {{body}} where each item's content should appear. This template is repeated for every list item.",
    defaultTemplate: `<tr>
  <td style="padding: 4px 0; font-size: 16px; line-height: 24px;">
    • {{text}}
  </td>
</tr>`,
    exampleMarkdown: "- A list item",
  },
  {
    key: "blockquote",
    label: "Blockquote",
    description: "> quoted text",
    placeholders: ["{{text}}"],
    defaultTemplate: `<tr>
  <td style="padding: 8px 40px;">
    <table cellpadding="0" cellspacing="0" border="0" width="100%">
      <tr>
        <td style="border-left: 4px solid ${EMAIL_COLORS.border}; padding-left: 16px; color: ${EMAIL_COLORS.mutedText};">
          {{text}}
        </td>
      </tr>
    </table>
  </td>
</tr>`,
    exampleMarkdown: "> This is a quote",
  },
  {
    key: "hr",
    label: "Horizontal Rule",
    description: "---",
    placeholders: [],
    defaultTemplate: `<tr>
  <td style="padding: 16px 40px;">
    <hr style="border: none; border-top: 1px solid ${EMAIL_COLORS.border}; margin: 0;" />
  </td>
</tr>`,
    exampleMarkdown: "---",
  },
];

function applyTemplate(template: string, vars: Record<string, string>): string {
  let result = template;
  for (const [key, value] of Object.entries(vars)) {
    result = result.replaceAll(`{{${key}}}`, value);
  }
  return result;
}

/**
 * Transform markdown content using layout-defined transformer rules.
 * Uses `marked` for parsing with custom renderers that apply the transformer templates.
 */
export function transformMarkdown(
  markdown: string,
  transformers: TransformerRules
): string {
  // Protect Handlebars expressions ({{...}}) from the markdown parser.
  // Characters like @ inside {{ }} can confuse marked's GFM inline rules (e.g. email autolinks)
  // and cause infinite recursion in parseInline.
  const handlebarsTokens: string[] = [];
  const safeMarkdown = markdown.replace(/\{\{.*?\}\}/gs, (match) => {
    const idx = handlebarsTokens.push(match) - 1;
    return `\x02HB${idx}\x03`;
  });

  function restoreHandlebars(html: string): string {
    // eslint-disable-next-line no-control-regex
    return html.replace(/\x02HB(\d+)\x03/g, (_, idx) => handlebarsTokens[parseInt(idx)]);
  }

  const renderer = new marked.Renderer();

  if (transformers.heading) {
    renderer.heading = ({ text, depth }: Tokens.Heading) => {
      return applyTemplate(transformers.heading!, {
        text: marked.parseInline(text, { renderer }) as string,
        level: String(depth),
      });
    };
  }

  if (transformers.paragraph) {
    renderer.paragraph = ({ text }: Tokens.Paragraph) => {
      return applyTemplate(transformers.paragraph!, {
        text: marked.parseInline(text, { renderer }) as string,
      });
    };
  }

  if (transformers.link) {
    renderer.link = ({ href, text }: Tokens.Link) => {
      return applyTemplate(transformers.link!, {
        text: marked.parseInline(text, { renderer }) as string,
        href: href || "",
      });
    };
  }

  if (transformers.image) {
    renderer.image = ({ href, text }: Tokens.Image) => {
      return applyTemplate(transformers.image!, {
        src: href || "",
        alt: text || "",
      });
    };
  }

  if (transformers.strong) {
    renderer.strong = ({ text }: Tokens.Strong) => {
      return applyTemplate(transformers.strong!, {
        text: marked.parseInline(text, { renderer }) as string,
      });
    };
  }

  if (transformers.em) {
    renderer.em = ({ text }: Tokens.Em) => {
      return applyTemplate(transformers.em!, {
        text: marked.parseInline(text, { renderer }) as string,
      });
    };
  }

  {
    const listTemplate = transformers.list ||
      TRANSFORMER_ELEMENT_TYPES.find((t) => t.key === "list")!.defaultTemplate;
    const listitemTemplate = transformers.listitem ||
      TRANSFORMER_ELEMENT_TYPES.find((t) => t.key === "listitem")!.defaultTemplate;

    renderer.list = ({ ordered, items }: Tokens.List) => {
      const renderedItems = items
        .map((item) => {
          const itemHtml = marked.parseInline(item.text, { renderer }) as string;
          return applyTemplate(listitemTemplate, { text: itemHtml, body: itemHtml });
        })
        .join("\n");

      return applyTemplate(listTemplate, {
        body: renderedItems,
        text: renderedItems,
        ordered: String(!!ordered),
      });
    };
  }

  if (transformers.blockquote) {
    renderer.blockquote = ({ text }: Tokens.Blockquote) => {
      return applyTemplate(transformers.blockquote!, {
        text: marked.parse(text, { renderer }) as string,
      });
    };
  }

  if (transformers.hr) {
    renderer.hr = () => {
      return transformers.hr!;
    };
  }

  if (transformers.codespan) {
    renderer.codespan = ({ text }: Tokens.Codespan) => {
      return applyTemplate(transformers.codespan!, { text });
    };
  }

  return restoreHandlebars(marked.parse(safeMarkdown, { renderer }) as string);
}

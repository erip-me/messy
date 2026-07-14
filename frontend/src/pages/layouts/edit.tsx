import { useState, useEffect } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { ArrowLeft, Save, Eye, Code, LayoutTemplate, Type, Plus, Trash2 } from "lucide-react";
import Editor from "@monaco-editor/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { getLayoutById, createLayout, updateLayout, Layout } from "@/api/layouts";
import {
  TransformerRules,
  TRANSFORMER_ELEMENT_TYPES,
  transformMarkdown,
} from "@/utils/markdown-transformer";
import toast from "react-hot-toast";
import { EMAIL_COLORS } from "@/lib/email-colors";
import { PreviewFrame } from "@/components/template-preview";

const DEFAULT_LAYOUT_BODY = `<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; background: ${EMAIL_COLORS.bodyBg}; }
    .preview-text { display: none; max-height: 0; overflow: hidden; mso-hide: all; }
    .wrapper { max-width: 600px; margin: 0 auto; padding: 24px; }
    .content { background: ${EMAIL_COLORS.contentBg}; border-radius: 8px; padding: 32px; }
    .footer { text-align: center; padding: 24px; color: ${EMAIL_COLORS.footerText}; font-size: 12px; }
  </style>
</head>
<body>
  <div class="preview-text">{{ preview }}</div>
  <div class="wrapper">
    <div class="content">
      {{ content }}
    </div>
    <div class="footer">
      &copy; {{ company.name }}
    </div>
  </div>
</body>
</html>`;

const DEFAULT_MARKDOWN_TEST = `# Welcome, {{ user.name }}!

Thanks for joining us. We're excited to have you on board.

**Here's what you can do next:**

- Explore your dashboard
- Set up your profile
- Connect your tools

[Get Started](https://example.com/dashboard)

---

> If you have any questions, just reply to this email.

*— The Team*`;

function MarkdownPreviewTab({
  layoutBody,
  transformers,
}: {
  layoutBody: string;
  transformers: TransformerRules;
}) {
  const [testMarkdown, setTestMarkdown] = useState(DEFAULT_MARKDOWN_TEST);

  const renderedHtml = (() => {
    try {
      let content = testMarkdown;
      content = content.replace(/\{\{\s*user\.name\s*\}\}/g, "John Doe");
      content = content.replace(/\{\{\s*company\.name\s*\}\}/g, "Acme Corp");
      content = content.replace(/\{\{\s*([\w.]+)\s*\}\}/g, (_, name) => name);
      content = transformMarkdown(content, transformers);

      let html = layoutBody;
      html = html.replace(/\{\{\s*content\s*\}\}/g, content);
      html = html.replace(/\{\{\s*preview\s*\}\}/g, "Preview text");
      html = html.replace(/\{\{\s*company\.name\s*\}\}/g, "Acme Corp");
      return html;
    } catch (e) {
      return `<p style="color:red;">Error: ${String(e)}</p>`;
    }
  })();

  return (
    <div className="space-y-3">
      <div>
        <Label className="text-xs text-muted-foreground">
          Test markdown (edit to see how your transformers render)
        </Label>
        <div className="border rounded-md overflow-hidden mt-1">
          <Editor
            height="150px"
            defaultLanguage="markdown"
            value={testMarkdown}
            onChange={(v) => setTestMarkdown(v || "")}
            options={{
              minimap: { enabled: false },
              lineNumbers: "off",
              wordWrap: "on",
              automaticLayout: true,
              theme: "vs-dark",
              fontSize: 13,
              lineDecorationsWidth: 0,
            }}
          />
        </div>
      </div>
      <div className="border rounded-md min-h-[300px] bg-card">
        <PreviewFrame html={renderedHtml} className="w-full border-0 min-h-[300px]" />
      </div>
    </div>
  );
}

export function LayoutEditPage() {
  const { id } = useParams();
  const navigate = useNavigate();

  const [layout, setLayout] = useState<Layout | null>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [apiKey] = useState("");

  const [formData, setFormData] = useState({
    name: "",
    body: DEFAULT_LAYOUT_BODY,
    transformers: {} as TransformerRules,
  });

  const isNew = !id || id === "new";
  const isEditMode = !isNew;

  useEffect(() => {
    loadData();
  }, [id]);

  const loadData = async () => {
    try {
      setLoading(true);
      if (isEditMode) {
        const data = await getLayoutById(parseInt(id!), apiKey);
        setLayout(data);
        setFormData({
          name: data.name,
          body: data.body,
          transformers: data.transformers || {},
        });
      }
    } catch {
      toast.error("Failed to load layout");
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    if (!formData.name.trim() || !formData.body.trim()) {
      toast.error("Please fill in all required fields");
      return;
    }

    if (!formData.body.includes("{{ content }}") && !formData.body.includes("{{content}}")) {
      toast.error("Layout body must contain a {{ content }} placeholder");
      return;
    }

    try {
      setSaving(true);

      const payload = {
        name: formData.name,
        body: formData.body,
        transformers: formData.transformers,
      };

      if (isEditMode && layout) {
        await updateLayout(layout.id, payload, apiKey);
        toast.success("Layout updated successfully");
      } else {
        await createLayout(payload, apiKey);
        toast.success("Layout created successfully");
        navigate("/layouts");
      }
    } catch {
      toast.error(`Failed to ${isEditMode ? "update" : "create"} layout`);
    } finally {
      setSaving(false);
    }
  };

  const renderPreview = () => {
    if (!formData.body) {
      return <div className="p-4 text-muted-foreground">No content to preview</div>;
    }

    const preview = formData.body
      .replace(/\{\{\s*content\s*\}\}/g, `<p style="color:${EMAIL_COLORS.placeholderText};font-style:italic;">[Template content will appear here]</p>`)
      .replace(/\{\{\s*preview\s*\}\}/g, 'Preview text from template will appear here')
      .replace(/\{\{\s*company\.name\s*\}\}/g, "Acme Corp");

    return <PreviewFrame html={preview} className="w-full border-0 min-h-[400px]" />;
  };

  if (loading) {
    return (
      <div className="p-6">
        <div className="flex items-center gap-4 mb-6">
          <Skeleton className="h-10 w-10" />
          <Skeleton className="h-8 w-64" />
        </div>
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="space-y-6">
            <Skeleton className="h-24" />
            <Skeleton className="h-96" />
          </div>
          <Skeleton className="h-96" />
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="sm" onClick={() => navigate("/layouts")}>
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div>
            <h1 className="page-heading">
              {isEditMode ? "Edit Layout" : "Create Layout"}
            </h1>
            {isEditMode && layout && (
              <p className="page-subtitle">Editing: {layout.name}</p>
            )}
          </div>
        </div>

        <Button onClick={handleSave} disabled={saving}>
          <Save className="h-4 w-4 mr-2" />
          {saving ? "Saving..." : "Save Layout"}
        </Button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Editor Panel */}
        <div className="space-y-6">
          {/* Basic Information */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <LayoutTemplate className="h-5 w-5" />
                Layout Information
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div>
                <Label htmlFor="name">Name *</Label>
                <Input
                  id="name"
                  value={formData.name}
                  onChange={(e) =>
                    setFormData((prev) => ({ ...prev, name: e.target.value }))
                  }
                  placeholder="Default Email Layout"
                />
              </div>
            </CardContent>
          </Card>

          {/* Layout Body Editor */}
          <Card className="flex-1">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Code className="h-5 w-5" />
                Layout Body *
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="border rounded-md overflow-hidden">
                <Editor
                  height="400px"
                  defaultLanguage="html"
                  value={formData.body}
                  onChange={(value) =>
                    setFormData((prev) => ({ ...prev, body: value || "" }))
                  }
                  options={{
                    minimap: { enabled: false },
                    lineNumbers: "on",
                    wordWrap: "on",
                    automaticLayout: true,
                    theme: "vs-dark",
                    fontSize: 14,
                    folding: true,
                    lineDecorationsWidth: 0,
                    lineNumbersMinChars: 3,
                  }}
                />
              </div>

              <div className="mt-4 p-3 bg-muted/50 rounded-md">
                <p className="text-sm text-muted-foreground mb-2">
                  <strong>Placeholders:</strong>
                </p>
                <div className="text-xs text-muted-foreground space-y-1">
                  <p>
                    <code>{"{{ content }}"}</code> <span className="text-destructive">(required)</span>: where template body is injected
                  </p>
                  <p>
                    <code>{"{{ preview }}"}</code>: inbox preview text (shown in Gmail, Outlook, etc.). Use inside a hidden element.
                  </p>
                  <p>
                    You can also use Liquid variables like{" "}
                    <code>{"{{ company.name }}"}</code>.
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Markdown Transformers */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Type className="h-5 w-5" />
                Markdown Transformers
              </CardTitle>
              <p className="text-sm text-muted-foreground">
                Define how markdown elements are converted to email HTML when templates use markdown mode.
              </p>
            </CardHeader>
            <CardContent>
              {(() => {
                const activeKeys = (Object.keys(formData.transformers) as (keyof TransformerRules)[]).filter(
                  (k) => formData.transformers[k] && TRANSFORMER_ELEMENT_TYPES.some((t) => t.key === k)
                );
                const availableTypes = TRANSFORMER_ELEMENT_TYPES.filter(
                  (t) => !activeKeys.includes(t.key)
                );

                return (
                  <div className="space-y-4">
                    {activeKeys.length === 0 && (
                      <p className="text-sm text-muted-foreground text-center py-4">
                        No transformers defined. Add one below to customize how markdown renders in email.
                      </p>
                    )}

                    <Accordion type="multiple" className="space-y-2">
                      {activeKeys.map((key) => {
                        const typeDef = TRANSFORMER_ELEMENT_TYPES.find(
                          (t) => t.key === key
                        )!;
                        return (
                          <AccordionItem
                            key={key}
                            value={key}
                            className="border rounded-md px-4"
                          >
                            <AccordionTrigger className="hover:no-underline">
                              <div className="flex items-center gap-2 text-sm">
                                <span className="font-medium">{typeDef.label}</span>
                                <span className="text-muted-foreground text-xs">
                                  {typeDef.description}
                                </span>
                              </div>
                            </AccordionTrigger>
                            <AccordionContent>
                              <div className="space-y-3">
                                <div className="flex items-center gap-2 text-xs text-muted-foreground">
                                  <span>Placeholders:</span>
                                  {typeDef.placeholders.map((p) => (
                                    <code
                                      key={p}
                                      className="bg-muted px-1.5 py-0.5 rounded"
                                    >
                                      {p}
                                    </code>
                                  ))}
                                </div>
                                <div className="border rounded-md overflow-hidden">
                                  <Editor
                                    height="200px"
                                    defaultLanguage="html"
                                    value={formData.transformers[key] || ""}
                                    onChange={(value) =>
                                      setFormData((prev) => ({
                                        ...prev,
                                        transformers: {
                                          ...prev.transformers,
                                          [key]: value || "",
                                        },
                                      }))
                                    }
                                    options={{
                                      minimap: { enabled: false },
                                      lineNumbers: "on",
                                      wordWrap: "on",
                                      automaticLayout: true,
                                      theme: "vs-dark",
                                      fontSize: 13,
                                      folding: true,
                                      lineDecorationsWidth: 0,
                                      lineNumbersMinChars: 3,
                                    }}
                                  />
                                </div>
                                {typeDef.hint && (
                                  <p className="text-xs text-muted-foreground">
                                    {typeDef.hint}
                                  </p>
                                )}
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  className="text-destructive hover:text-destructive"
                                  onClick={() =>
                                    setFormData((prev) => {
                                      const next = { ...prev.transformers };
                                      delete next[key];
                                      return { ...prev, transformers: next };
                                    })
                                  }
                                >
                                  <Trash2 className="h-3.5 w-3.5 mr-1.5" />
                                  Remove
                                </Button>
                              </div>
                            </AccordionContent>
                          </AccordionItem>
                        );
                      })}
                    </Accordion>

                    {availableTypes.length > 0 && (
                      <div className="flex flex-wrap gap-2 pt-2 border-t">
                        {availableTypes.map((typeDef) => (
                          <Button
                            key={typeDef.key}
                            variant="outline"
                            size="sm"
                            onClick={() =>
                              setFormData((prev) => ({
                                ...prev,
                                transformers: {
                                  ...prev.transformers,
                                  [typeDef.key]: typeDef.defaultTemplate,
                                },
                              }))
                            }
                          >
                            <Plus className="h-3.5 w-3.5 mr-1" />
                            {typeDef.label}
                          </Button>
                        ))}
                      </div>
                    )}
                  </div>
                );
              })()}
            </CardContent>
          </Card>
        </div>

        {/* Preview Panel */}
        <div className="lg:sticky lg:top-6">
          <Card className="h-fit">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Eye className="h-5 w-5" />
                Live Preview
              </CardTitle>
            </CardHeader>
            <CardContent>
              <Tabs defaultValue="rendered">
                <TabsList className="grid w-full grid-cols-3">
                  <TabsTrigger value="rendered">Rendered</TabsTrigger>
                  <TabsTrigger value="markdown">Markdown Test</TabsTrigger>
                  <TabsTrigger value="html">HTML Source</TabsTrigger>
                </TabsList>

                <TabsContent value="rendered" className="mt-4">
                  <div className="border rounded-md min-h-[400px] bg-card">
                    {renderPreview()}
                  </div>
                </TabsContent>

                <TabsContent value="markdown" className="mt-4">
                  <MarkdownPreviewTab
                    layoutBody={formData.body}
                    transformers={formData.transformers}
                  />
                </TabsContent>

                <TabsContent value="html" className="mt-4">
                  <div className="border rounded-md overflow-hidden">
                    <Editor
                      height="400px"
                      defaultLanguage="html"
                      value={formData.body}
                      options={{
                        readOnly: true,
                        minimap: { enabled: false },
                        lineNumbers: "on",
                        wordWrap: "on",
                        automaticLayout: true,
                        theme: "vs-light",
                        fontSize: 12,
                      }}
                    />
                  </div>
                </TabsContent>
              </Tabs>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}

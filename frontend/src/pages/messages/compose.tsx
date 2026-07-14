import React, { useState, useEffect } from "react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { ArrowLeft, Paperclip, Send, X } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Badge } from "@/components/ui/badge";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  sendMessage,
  triggerMessage,
  SendMessageRequest,
  getWhatsAppTemplates,
  WhatsAppTemplate,
} from "@/api/messages";
import { getTemplates, Template } from "@/api/templates";
import { getLayouts, Layout } from "@/api/layouts";
import { getFolders, Folder as FolderType } from "@/api/folders";
import { TemplateTreePicker } from "@/components/template-tree-picker";
import { getSendingIdentities, SendingIdentity } from "@/api/sending-identities";
import { RequiredAsterisk } from "@/components/ui/required-asterisk";
import { ChannelTypeIcon } from "@/components/channel-icons";
import { CHANNEL_CONFIG, Channel } from "@/utils/channel-config";
import { transformMarkdown } from "@/utils/markdown-transformer";
import DOMPurify from "dompurify";
import toast from "react-hot-toast";
import { useActiveEnvironment } from "@/hooks/useActiveEnvironment";

// Merge tags the server fills in automatically, so we don't ask the sender for them.
const AUTO_MERGE_TAGS = new Set(["unsubscribe_url"]);

export function MessageComposePage() {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const activeEnvId = useActiveEnvironment();
  const [apiKey] = useState("");

  const [templates, setTemplates] = useState<Template[]>([]);
  const [folders, setFolders] = useState<FolderType[]>([]);
  const [layouts, setLayouts] = useState<Layout[]>([]);
  const [sending, setSending] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  // Determine initial mode from query params
  const hasTemplateParam = !!searchParams.get("template_id");
  const initialChannel = (searchParams.get("channel") || "email") as Channel;

  const [mode, setMode] = useState<"template" | "direct">(
    hasTemplateParam ? "template" : "direct"
  );

  // Direct mode state
  const [formData, setFormData] = useState<SendMessageRequest>({
    channel: initialChannel,
    to: "",
    cc: "",
    bcc: "",
    subject: "",
    body: "",
  });
  const [attachments, setAttachments] = useState<File[]>([]);
  const [identities, setIdentities] = useState<SendingIdentity[]>([]);
  const [ccRecipients, setCcRecipients] = useState<string[]>([]);
  const [bccRecipients, setBccRecipients] = useState<string[]>([]);
  const [showCcBcc, setShowCcBcc] = useState(false);

  // WhatsApp native template state
  const [waTemplates, setWaTemplates] = useState<WhatsAppTemplate[]>([]);
  const [selectedWaTemplate, setSelectedWaTemplate] = useState<string>("");
  const [waParams, setWaParams] = useState<string[]>([]);

  // Template mode state
  const [selectedTemplate, setSelectedTemplate] = useState<string>("");
  const [templateTo, setTemplateTo] = useState("");
  const [templateCcRecipients, setTemplateCcRecipients] = useState<string[]>([]);
  const [templateBccRecipients, setTemplateBccRecipients] = useState<string[]>([]);
  const [showTemplateCcBcc, setShowTemplateCcBcc] = useState(false);
  const [mergeTagValues, setMergeTagValues] = useState<Record<string, string>>(
    {}
  );
  const [detectedMergeTags, setDetectedMergeTags] = useState<string[]>([]);

  useEffect(() => {
    loadData();
  }, [activeEnvId]);

  const loadData = async () => {
    try {
      const [templatesData, layoutsData, foldersData] = await Promise.all([
        getTemplates(apiKey),
        getLayouts(apiKey),
        getFolders(apiKey).catch(() => [] as FolderType[]),
      ]);
      setTemplates(templatesData);
      setLayouts(layoutsData);
      setFolders(foldersData);
      getSendingIdentities().then(setIdentities).catch(() => {});

      const templateId = searchParams.get("template_id");
      if (templateId) {
        const template = templatesData.find(
          (t) => t.id.toString() === templateId
        );
        if (template) {
          setSelectedTemplate(templateId);
          extractMergeTags(template.body, template.subject);
        }
      }
    } catch (error) {
      console.error("Failed to load data:", error);
    }
  };

  const extractMergeTags = (body: string, subject?: string) => {
    const combined = `${body} ${subject || ""}`;
    const matches =
      combined.match(/\{\{\s*([a-zA-Z0-9_.]+)\s*\}\}/g) || [];
    const tags = [
      ...new Set(
        matches.map((m) =>
          m.replace(/\{\{\s*/, "").replace(/\s*\}\}/, "")
        )
      ),
    ].filter((tag) => !AUTO_MERGE_TAGS.has(tag));
    setDetectedMergeTags(tags);
    setMergeTagValues((prev) => {
      const next: Record<string, string> = {};
      tags.forEach((tag) => {
        next[tag] = prev[tag] || "";
      });
      return next;
    });
  };

  const handleChannelChange = (channel: string) => {
    const def = CHANNEL_CONFIG[channel as Channel];
    setFormData((prev) => ({
      ...prev,
      channel: channel as Channel,
      cc: channel === "email" ? prev.cc : "",
      bcc: channel === "email" ? prev.bcc : "",
      subject: def.hasSubject ? prev.subject : "",
    }));
    if (channel === "whatsapp" && waTemplates.length === 0) {
      getWhatsAppTemplates()
        .then(setWaTemplates)
        .catch(() => {});
    }
    if (channel !== "whatsapp") {
      setSelectedWaTemplate("");
      setWaParams([]);
    }
  };

  const handleInputChange = (
    field: keyof SendMessageRequest,
    value: string
  ) => {
    setFormData((prev) => ({ ...prev, [field]: value }));
  };

  const handleTemplateSelect = (templateId: string) => {
    if (!templateId || templateId === "none") {
      setSelectedTemplate("");
      setDetectedMergeTags([]);
      setMergeTagValues({});
      return;
    }

    const template = templates.find((t) => t.id.toString() === templateId);
    if (template) {
      setSelectedTemplate(templateId);
      extractMergeTags(template.body, template.subject);
    }
  };

  const handleWaTemplateSelect = (templateName: string) => {
    setSelectedWaTemplate(templateName);
    if (!templateName) {
      setWaParams([]);
      return;
    }
    const tpl = waTemplates.find((t) => t.name === templateName);
    if (tpl) {
      // Extract parameter count from body component
      const bodyComponent = tpl.components.find((c) => c.type === "BODY");
      const matches = bodyComponent?.text?.match(/\{\{\d+\}\}/g) || [];
      setWaParams(new Array(matches.length).fill(""));
    }
  };

  const addRecipient = (type: "cc" | "bcc", email: string) => {
    if (!email.trim()) return;
    if (type === "cc") {
      setCcRecipients((prev) => [...prev, email.trim()]);
    } else {
      setBccRecipients((prev) => [...prev, email.trim()]);
    }
  };

  const removeRecipient = (type: "cc" | "bcc", index: number) => {
    if (type === "cc") {
      setCcRecipients((prev) => prev.filter((_, i) => i !== index));
    } else {
      setBccRecipients((prev) => prev.filter((_, i) => i !== index));
    }
  };

  const handleSend = async () => {
    setSubmitted(true);

    if (mode === "template") {
      if (!templateTo.trim()) {
        toast.error("Please enter a recipient");
        return;
      }
      if (!selectedTemplate) {
        toast.error("Please select a template");
        return;
      }
      const missingTags = detectedMergeTags.filter(
        (tag) => !mergeTagValues[tag]?.trim()
      );
      if (missingTags.length > 0) {
        toast.error(
          `Missing merge tags: ${missingTags.map((t) => `{{ ${t} }}`).join(", ")}`
        );
        return;
      }

      try {
        setSending(true);
        const tpl = templates.find(
          (t) => t.id.toString() === selectedTemplate
        )!;
        await triggerMessage(
          {
            trigger: tpl.trigger,
            channel: tpl.channel,
            to: templateTo,
            data: mergeTagValues,
          },
          apiKey
        );
        toast.success("Message sent successfully");
        navigate("/messages");
      } catch (error: any) {
        toast.error(
          error.response?.data?.message || "Failed to send message"
        );
      } finally {
        setSending(false);
      }
    } else {
      // WhatsApp native template mode
      if (formData.channel === "whatsapp" && selectedWaTemplate) {
        if (!formData.to.trim()) {
          toast.error("Please enter a phone number");
          return;
        }
        const missingParams = waParams.some((p) => !p.trim());
        if (missingParams && waParams.length > 0) {
          toast.error("Please fill in all template parameters");
          return;
        }

        try {
          setSending(true);
          const tpl = waTemplates.find((t) => t.name === selectedWaTemplate);
          await sendMessage(
            {
              ...formData,
              subject: selectedWaTemplate,
              body: "",
              tags: waParams.filter((p) => p.trim()),
              language: tpl?.language || "en",
            },
            apiKey
          );
          toast.success("WhatsApp template message sent");
          navigate("/messages");
        } catch (error: any) {
          toast.error(
            error.response?.data?.message || "Failed to send message"
          );
        } finally {
          setSending(false);
        }
        return;
      }

      if (!formData.to.trim() || !formData.body.trim()) {
        toast.error("Please fill in all required fields");
        return;
      }
      const channelDef = CHANNEL_CONFIG[formData.channel as Channel];
      if (channelDef.hasSubject && !formData.subject?.trim()) {
        toast.error(
          `${channelDef.subjectLabel} is required for ${channelDef.name} messages`
        );
        return;
      }

      try {
        setSending(true);
        await sendMessage(
          {
            ...formData,
            cc:
              ccRecipients.length > 0
                ? ccRecipients.join(",")
                : undefined,
            bcc:
              bccRecipients.length > 0
                ? bccRecipients.join(",")
                : undefined,
            attachments:
              attachments.length > 0 ? attachments : undefined,
          },
          apiKey
        );
        toast.success("Message sent successfully");
        navigate("/messages");
      } catch (error: any) {
        toast.error(
          error.response?.data?.message || "Failed to send message"
        );
      } finally {
        setSending(false);
      }
    }
  };

  // --- Preview helpers ---

  const replaceMergeTags = (text: string): string => {
    let result = text;
    for (const [tag, value] of Object.entries(mergeTagValues)) {
      if (value) {
        result = result.replaceAll(
          new RegExp(
            `\\{\\{\\s*${tag.replace(".", "\\.")}\\s*\\}\\}`,
            "g"
          ),
          value
        );
      }
    }
    return result;
  };

  const selectedTpl = selectedTemplate
    ? templates.find((t) => t.id.toString() === selectedTemplate)
    : null;

  const currentChannelDef =
    mode === "template" && selectedTpl
      ? CHANNEL_CONFIG[selectedTpl.channel as Channel]
      : CHANNEL_CONFIG[formData.channel as Channel];

  const renderPreview = () => {
    if (mode === "template") {
      if (!selectedTpl) {
        return (
          <div className="p-8 text-center text-muted-foreground">
            Select a template to see preview
          </div>
        );
      }

      try {
        let preview = replaceMergeTags(selectedTpl.body);

        if (selectedTpl.body_format === "markdown") {
          const layout = selectedTpl.layout_id
            ? layouts.find((l) => l.id === selectedTpl.layout_id)
            : null;
          preview = transformMarkdown(preview, layout?.transformers || {});
        }

        if (selectedTpl.layout_id) {
          const layout = layouts.find(
            (l) => l.id === selectedTpl.layout_id
          );
          if (layout) {
            let layoutHtml = replaceMergeTags(layout.body);
            layoutHtml = layoutHtml.replace(
              /\{\{\s*content\s*\}\}/g,
              preview
            );
            layoutHtml = layoutHtml.replace(
              /\{\{\s*preview\s*\}\}/g,
              replaceMergeTags(selectedTpl.preview || "")
            );
            preview = layoutHtml;
          }
        }

        if (selectedTpl.layout_id) {
          return (
            <iframe
              sandbox="allow-same-origin"
              srcDoc={preview}
              className="w-full border-0 min-h-[500px]"
              onLoad={(e) => {
                const iframe = e.target as HTMLIFrameElement;
                if (iframe.contentDocument) {
                  iframe.style.height =
                    iframe.contentDocument.documentElement.scrollHeight +
                    "px";
                }
              }}
            />
          );
        }

        return (
          <div
            className="p-4 prose prose-sm max-w-none"
            dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(preview) }}
          />
        );
      } catch {
        return (
          <div className="p-4 text-destructive text-sm">Preview error</div>
        );
      }
    }

    // Direct mode preview
    if (!formData.body) {
      return (
        <div className="p-8 text-center text-muted-foreground">
          Start typing to see preview
        </div>
      );
    }

    return (
      <div className="p-4">
        {currentChannelDef.hasSubject && formData.subject && (
          <div className="mb-3 pb-2 border-b">
            <div className="text-xs text-muted-foreground">
              {currentChannelDef.subjectLabel}:
            </div>
            <div className="font-medium text-sm">{formData.subject}</div>
          </div>
        )}
        <div
          className="prose prose-sm max-w-none"
          dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(formData.body) }}
        />
      </div>
    );
  };

  // --- Recipient label helper ---
  const recipientLabel =
    mode === "template" && selectedTpl
      ? selectedTpl.channel === "email"
        ? "To (Email Address)"
        : selectedTpl.channel === "push"
          ? "Device Token"
          : "Phone Number"
      : formData.channel === "email"
        ? "To (Email Address)"
        : formData.channel === "push"
          ? "Device Token"
          : "Phone Number";

  const recipientPlaceholder =
    mode === "template" && selectedTpl
      ? selectedTpl.channel === "email"
        ? "user@example.com"
        : selectedTpl.channel === "push"
          ? "device-token-123"
          : "+1234567890"
      : formData.channel === "email"
        ? "user@example.com"
        : formData.channel === "push"
          ? "device-token-123"
          : "+1234567890";

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between mb-6">
        <div className="flex items-center gap-4">
          <Button
            variant="ghost"
            size="sm"
            onClick={() => navigate("/messages")}
          >
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <h1 className="page-heading">Compose Message</h1>
        </div>

        <Button onClick={handleSend} disabled={sending}>
          <Send className="h-4 w-4 mr-2" />
          {sending ? "Sending..." : "Send Message"}
        </Button>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Left: Template / Direct tabs */}
        <Card>
          <CardContent className="p-0">
            <Tabs
              value={mode}
              onValueChange={(v) => setMode(v as "template" | "direct")}
            >
              <TabsList className="w-full justify-stretch rounded-b-none border-b bg-transparent p-0 h-auto">
                <TabsTrigger
                  value="template"
                  className="flex-1 -mb-px rounded-none border-b-2 border-transparent py-3 text-muted-foreground data-[state=active]:border-primary data-[state=active]:bg-transparent data-[state=active]:text-foreground data-[state=active]:font-semibold data-[state=active]:shadow-none"
                >
                  Template
                </TabsTrigger>
                <TabsTrigger
                  value="direct"
                  className="flex-1 -mb-px rounded-none border-b-2 border-transparent py-3 text-muted-foreground data-[state=active]:border-primary data-[state=active]:bg-transparent data-[state=active]:text-foreground data-[state=active]:font-semibold data-[state=active]:shadow-none"
                >
                  Direct
                </TabsTrigger>
              </TabsList>

              {/* Template mode */}
              <TabsContent value="template" className="p-4 space-y-4 mt-0">
                <div>
                  <Label>Template</Label>
                  <TemplateTreePicker
                    templates={templates}
                    folders={folders}
                    value={selectedTemplate}
                    onChange={handleTemplateSelect}
                    allowNone
                  />
                </div>

                {selectedTpl && (
                  <div>
                    <Label>Channel</Label>
                    <div className="grid grid-cols-2 gap-2 mt-1">
                      {(Object.keys(CHANNEL_CONFIG) as Channel[]).map(
                        (channel) => (
                          <Button
                            key={channel}
                            variant={
                              selectedTpl.channel === channel
                                ? "default"
                                : "outline"
                            }
                            disabled
                            className="flex items-center gap-2 justify-start h-9 text-sm disabled:opacity-100"
                            size="sm"
                          >
                            <ChannelTypeIcon type={channel} size={14} />
                            <span>{CHANNEL_CONFIG[channel].name}</span>
                          </Button>
                        )
                      )}
                    </div>
                    <p className="text-xs text-muted-foreground mt-1">
                      Channel is set by the selected template.
                    </p>
                  </div>
                )}

                <div>
                  <Label>
                    {recipientLabel}{" "}
                    <RequiredAsterisk
                      error={submitted && !templateTo.trim()}
                    />
                  </Label>
                  <Input
                    value={templateTo}
                    onChange={(e) => setTemplateTo(e.target.value)}
                    placeholder={recipientPlaceholder}
                  />
                </div>

                {selectedTpl?.channel === "email" && !showTemplateCcBcc && (
                  <button
                    type="button"
                    className="text-sm text-primary hover:underline"
                    onClick={() => setShowTemplateCcBcc(true)}
                  >
                    Add CC / BCC
                  </button>
                )}
                {selectedTpl?.channel === "email" && showTemplateCcBcc && (
                  <>
                    <div>
                      <Label>CC</Label>
                      <div className="space-y-2">
                        {templateCcRecipients.length > 0 && (
                          <div className="flex flex-wrap gap-1">
                            {templateCcRecipients.map((email, index) => (
                              <Badge
                                key={index}
                                variant="outline"
                                className="flex items-center gap-1"
                              >
                                {email}
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  className="h-auto p-0.5"
                                  onClick={() =>
                                    setTemplateCcRecipients((prev) =>
                                      prev.filter((_, i) => i !== index)
                                    )
                                  }
                                >
                                  <X className="h-3 w-3" />
                                </Button>
                              </Badge>
                            ))}
                          </div>
                        )}
                        <Input
                          placeholder="user@example.com"
                          className="h-8 text-sm"
                          onKeyPress={(e) => {
                            if (e.key === "Enter") {
                              const val = e.currentTarget.value.trim();
                              if (val) {
                                setTemplateCcRecipients((prev) => [...prev, val]);
                                e.currentTarget.value = "";
                              }
                            }
                          }}
                        />
                      </div>
                    </div>
                    <div>
                      <Label>BCC</Label>
                      <div className="space-y-2">
                        {templateBccRecipients.length > 0 && (
                          <div className="flex flex-wrap gap-1">
                            {templateBccRecipients.map((email, index) => (
                              <Badge
                                key={index}
                                variant="outline"
                                className="flex items-center gap-1"
                              >
                                {email}
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  className="h-auto p-0.5"
                                  onClick={() =>
                                    setTemplateBccRecipients((prev) =>
                                      prev.filter((_, i) => i !== index)
                                    )
                                  }
                                >
                                  <X className="h-3 w-3" />
                                </Button>
                              </Badge>
                            ))}
                          </div>
                        )}
                        <Input
                          placeholder="user@example.com"
                          className="h-8 text-sm"
                          onKeyPress={(e) => {
                            if (e.key === "Enter") {
                              const val = e.currentTarget.value.trim();
                              if (val) {
                                setTemplateBccRecipients((prev) => [...prev, val]);
                                e.currentTarget.value = "";
                              }
                            }
                          }}
                        />
                      </div>
                    </div>
                  </>
                )}

                {detectedMergeTags.length > 0 && (
                  <div className="border-t pt-4">
                    <Label className="text-xs text-muted-foreground uppercase tracking-wide">
                      Merge Tags
                    </Label>
                    <div className="mt-2 border rounded-md overflow-hidden">
                      {detectedMergeTags.map((tag, i) => (
                        <div
                          key={tag}
                          className={`flex items-center ${i > 0 ? "border-t" : ""}`}
                        >
                          <code className="shrink-0 px-3 py-1.5 text-xs text-muted-foreground bg-muted border-r font-mono w-[140px] truncate" title={`{{ ${tag} }}`}>
                            {tag}
                          </code>
                          <input
                            value={mergeTagValues[tag] || ""}
                            onChange={(e) =>
                              setMergeTagValues((prev) => ({
                                ...prev,
                                [tag]: e.target.value,
                              }))
                            }
                            placeholder="value"
                            className="flex-1 px-3 py-1.5 text-sm bg-transparent outline-none"
                          />
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </TabsContent>

              {/* Direct mode */}
              <TabsContent value="direct" className="p-4 space-y-4 mt-0">
                <div>
                  <Label>Channel</Label>
                  <div className="grid grid-cols-2 gap-2 mt-1">
                    {(Object.keys(CHANNEL_CONFIG) as Channel[]).map(
                      (channel) => (
                        <Button
                          key={channel}
                          variant={
                            formData.channel === channel
                              ? "default"
                              : "outline"
                          }
                          onClick={() => handleChannelChange(channel)}
                          className="flex items-center gap-2 justify-start h-9 text-sm"
                          size="sm"
                        >
                          <ChannelTypeIcon type={channel} size={14} className={formData.channel === channel ? "text-primary-foreground" : undefined} />
                          <span>{CHANNEL_CONFIG[channel].name}</span>
                        </Button>
                      )
                    )}
                  </div>
                </div>

                <div>
                  <Label>
                    {recipientLabel}{" "}
                    <RequiredAsterisk
                      error={submitted && !formData.to.trim()}
                    />
                  </Label>
                  <Input
                    value={formData.to}
                    onChange={(e) => handleInputChange("to", e.target.value)}
                    placeholder={recipientPlaceholder}
                  />
                </div>

                {formData.channel === "email" && identities.length > 0 && (
                  <div>
                    <Label>From</Label>
                    <Select
                      value={formData.sending_identity_id ? String(formData.sending_identity_id) : "default"}
                      onValueChange={(v) => setFormData((prev) => ({ ...prev, sending_identity_id: v === "default" ? null : Number(v) }))}
                    >
                      <SelectTrigger><SelectValue /></SelectTrigger>
                      <SelectContent>
                        <SelectItem value="default">Default (channel from address)</SelectItem>
                        {identities.map((i) => (
                          <SelectItem key={i.id} value={String(i.id)}>{i.from_name ? `${i.from_name} <${i.from_email}>` : i.from_email}</SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>
                )}

                {formData.channel === "whatsapp" && (
                  <>
                    <div className="rounded-lg border border-yellow-200 bg-yellow-50 p-3 text-sm text-yellow-800">
                      <p className="font-medium mb-1">WhatsApp messaging rules</p>
                      <ul className="list-disc pl-4 space-y-0.5 text-xs">
                        <li><strong>Template messages</strong> can be sent anytime but require Meta approval and user opt-in for marketing</li>
                        <li><strong>Text messages</strong> can only be sent within 24 hours of the user&apos;s last message to you</li>
                        <li>Utility &amp; authentication templates have fewer restrictions than marketing templates</li>
                      </ul>
                    </div>

                    <div>
                      <Label>WhatsApp Template (optional)</Label>
                      <Select
                        value={selectedWaTemplate || "none"}
                        onValueChange={(v) => handleWaTemplateSelect(v === "none" ? "" : v)}
                      >
                        <SelectTrigger>
                          <SelectValue placeholder="Send as text message (no template)" />
                        </SelectTrigger>
                        <SelectContent>
                          <SelectItem value="none">Send as text message</SelectItem>
                          {waTemplates.map((t) => (
                            <SelectItem key={`${t.name}-${t.language}`} value={t.name}>
                              <div className="flex items-center gap-2">
                                <span>{t.name}</span>
                                <span className="text-xs text-muted-foreground">
                                  {t.category.toLowerCase()} · {t.language}
                                </span>
                              </div>
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    </div>

                    {selectedWaTemplate && (() => {
                      const tpl = waTemplates.find((t) => t.name === selectedWaTemplate);
                      const bodyComponent = tpl?.components.find((c) => c.type === "BODY");
                      return (
                        <div className="space-y-3">
                          {bodyComponent?.text && (
                            <div className="rounded-lg border bg-muted/30 p-3">
                              <Label className="text-xs text-muted-foreground mb-1 block">Template preview</Label>
                              <p className="text-sm whitespace-pre-wrap">{bodyComponent.text}</p>
                            </div>
                          )}
                          {waParams.length > 0 && (
                            <div className="space-y-2">
                              <Label>Template parameters</Label>
                              {waParams.map((val, i) => (
                                <Input
                                  key={i}
                                  value={val}
                                  onChange={(e) => {
                                    const next = [...waParams];
                                    next[i] = e.target.value;
                                    setWaParams(next);
                                  }}
                                  placeholder={`Parameter {{${i + 1}}}`}
                                />
                              ))}
                            </div>
                          )}
                        </div>
                      );
                    })()}
                  </>
                )}

                {formData.channel === "email" && !showCcBcc && (
                  <button
                    type="button"
                    className="text-sm text-primary hover:underline"
                    onClick={() => setShowCcBcc(true)}
                  >
                    Add CC / BCC
                  </button>
                )}
                {formData.channel === "email" && showCcBcc && (
                  <>
                    <div>
                      <Label>CC</Label>
                      <div className="space-y-2">
                        {ccRecipients.length > 0 && (
                          <div className="flex flex-wrap gap-1">
                            {ccRecipients.map((email, index) => (
                              <Badge
                                key={index}
                                variant="outline"
                                className="flex items-center gap-1"
                              >
                                {email}
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  className="h-auto p-0.5"
                                  onClick={() =>
                                    removeRecipient("cc", index)
                                  }
                                >
                                  <X className="h-3 w-3" />
                                </Button>
                              </Badge>
                            ))}
                          </div>
                        )}
                        <div className="flex gap-2">
                          <Input
                            placeholder="user@example.com"
                            className="h-8 text-sm"
                            onKeyPress={(e) => {
                              if (e.key === "Enter") {
                                addRecipient(
                                  "cc",
                                  e.currentTarget.value
                                );
                                e.currentTarget.value = "";
                              }
                            }}
                          />
                        </div>
                      </div>
                    </div>
                    <div>
                      <Label>BCC</Label>
                      <div className="space-y-2">
                        {bccRecipients.length > 0 && (
                          <div className="flex flex-wrap gap-1">
                            {bccRecipients.map((email, index) => (
                              <Badge
                                key={index}
                                variant="outline"
                                className="flex items-center gap-1"
                              >
                                {email}
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  className="h-auto p-0.5"
                                  onClick={() =>
                                    removeRecipient("bcc", index)
                                  }
                                >
                                  <X className="h-3 w-3" />
                                </Button>
                              </Badge>
                            ))}
                          </div>
                        )}
                        <div className="flex gap-2">
                          <Input
                            placeholder="user@example.com"
                            className="h-8 text-sm"
                            onKeyPress={(e) => {
                              if (e.key === "Enter") {
                                addRecipient(
                                  "bcc",
                                  e.currentTarget.value
                                );
                                e.currentTarget.value = "";
                              }
                            }}
                          />
                        </div>
                      </div>
                    </div>
                  </>
                )}

                {currentChannelDef.hasSubject && (
                  <div>
                    <Label>
                      {currentChannelDef.subjectLabel}{" "}
                      <RequiredAsterisk
                        error={
                          submitted && !formData.subject?.trim()
                        }
                      />
                    </Label>
                    <Input
                      value={formData.subject}
                      onChange={(e) =>
                        handleInputChange("subject", e.target.value)
                      }
                      placeholder={`${currentChannelDef.name} ${currentChannelDef.subjectLabel?.toLowerCase()}`}
                    />
                  </div>
                )}

                {!(formData.channel === "whatsapp" && selectedWaTemplate) && (
                  <div>
                    <Label>
                      Message Body{" "}
                      <RequiredAsterisk
                        error={submitted && !formData.body.trim()}
                      />
                      {currentChannelDef.maxLength && (
                        <span className="text-muted-foreground ml-2 font-normal">
                          ({formData.body.length}/
                          {currentChannelDef.maxLength})
                        </span>
                      )}
                    </Label>
                    <Textarea
                      value={formData.body}
                      onChange={(e) =>
                        handleInputChange("body", e.target.value)
                      }
                      placeholder="Type your message here..."
                      className="min-h-[200px]"
                      maxLength={currentChannelDef.maxLength}
                    />
                  </div>
                )}

                {formData.channel === "email" && (
                  <div>
                    <Label className="flex items-center gap-1.5">
                      <Paperclip className="h-3.5 w-3.5" />
                      Attachments
                    </Label>
                    {attachments.length > 0 && (
                      <div className="mt-2 space-y-1">
                        {attachments.map((file, index) => (
                          <div
                            key={index}
                            className="flex items-center justify-between p-2 border rounded-md text-sm"
                          >
                            <div className="min-w-0 flex-1">
                              <span className="truncate block">{file.name}</span>
                              <span className="text-xs text-muted-foreground">
                                {(file.size / 1024).toFixed(1)} KB
                              </span>
                            </div>
                            <Button
                              variant="ghost"
                              size="sm"
                              className="h-auto p-1 shrink-0"
                              onClick={() =>
                                setAttachments((prev) =>
                                  prev.filter((_, i) => i !== index)
                                )
                              }
                            >
                              <X className="h-3.5 w-3.5" />
                            </Button>
                          </div>
                        ))}
                      </div>
                    )}
                    <div className="mt-2">
                      <input
                        type="file"
                        multiple
                        className="hidden"
                        id="attachment-input"
                        onChange={(e) => {
                          if (e.target.files) {
                            setAttachments((prev) => [
                              ...prev,
                              ...Array.from(e.target.files!),
                            ]);
                            e.target.value = "";
                          }
                        }}
                      />
                      <Button
                        variant="outline"
                        size="sm"
                        onClick={() =>
                          document.getElementById("attachment-input")?.click()
                        }
                      >
                        <Paperclip className="h-3.5 w-3.5 mr-1.5" />
                        Add files
                      </Button>
                    </div>
                  </div>
                )}
              </TabsContent>
            </Tabs>
          </CardContent>
        </Card>

        {/* Right: Live Preview */}
        <Card className="lg:sticky lg:top-6 lg:self-start">
          <CardHeader className="pb-2">
            <CardTitle className="text-sm text-muted-foreground">
              Live Preview
            </CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <div className="border-t">{renderPreview()}</div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

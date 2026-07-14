import React, { useState, useEffect, useRef } from "react";
import { useNavigate, useParams, useSearchParams } from "react-router-dom";
import { ArrowLeft, Save, Eye, Code, FileText, Folder, FolderPlus, LayoutTemplate, Smile, SendHorizonal } from "lucide-react";
import Editor from "@monaco-editor/react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { SearchableSelect } from "@/components/ui/searchable-select";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { Skeleton } from "@/components/ui/skeleton";
import {
  getTemplateById,
  createTemplate,
  updateTemplate,
  Template,
  TemplateChannel,
  BodyFormat,
} from "@/api/templates";
import {
  getFolders,
  createFolder as createFolderApi,
  Folder as FolderType,
} from "@/api/folders";
import { getLayouts, Layout } from "@/api/layouts";
import { ChannelTypeIcon } from "@/components/channel-icons";
import { CHANNEL_CONFIG, Channel } from "@/utils/channel-config";
import { Switch } from "@/components/ui/switch";
import { transformMarkdown } from "@/utils/markdown-transformer";
import { PreviewFrame, PlaintextPreview } from "@/components/template-preview";
import EmojiPicker, { EmojiClickData } from "emoji-picker-react";
import toast from "react-hot-toast";

export function TemplateEditPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const [apiKey] = useState("");

  const [template, setTemplate] = useState<Template | null>(null);
  const [folders, setFolders] = useState<FolderType[]>([]);
  const [layouts, setLayouts] = useState<Layout[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  // Track whether the user has manually edited the subject
  const subjectTouchedRef = useRef(false);
  const subjectInputRef = useRef<HTMLInputElement>(null);
  const [emojiPickerOpen, setEmojiPickerOpen] = useState(false);

  // Folder creation dialog
  const [createFolderOpen, setCreateFolderOpen] = useState(false);
  const [newFolderName, setNewFolderName] = useState("");
  const [creatingFolder, setCreatingFolder] = useState(false);

  // Form state
  const [formData, setFormData] = useState({
    name: "",
    trigger: "",
    channel: "email" as TemplateChannel,
    subject: "",
    body: "",
    body_format: "html" as BodyFormat,
    preview: "",
    folder_id: (searchParams.get("folder_id") ? parseInt(searchParams.get("folder_id")!) : undefined) as number | undefined,
    layout_id: undefined as number | undefined,
  });

  const isNew = !id || id === "new";
  const isEditMode = !isNew;
  const channelDef = CHANNEL_CONFIG[formData.channel];

  const currentFolder = folders.find(f => f.id === formData.folder_id);

  const getFolderUrlPath = (folderId: number): string => {
    const folder = folders.find(f => f.id === folderId);
    if (!folder) return '';
    if (folder.parent_folder_id) {
      const parentPath = getFolderUrlPath(folder.parent_folder_id);
      return parentPath ? `${parentPath}/${folder.name}` : folder.name;
    }
    return folder.name;
  };

  // Build a flat list of folders ordered as a tree with depth info
  const getFolderTree = (): { folder: FolderType; depth: number }[] => {
    const result: { folder: FolderType; depth: number }[] = [];
    const roots = folders.filter((f) => !f.parent_folder_id);
    const childrenMap = new Map<number, FolderType[]>();
    for (const f of folders) {
      if (f.parent_folder_id) {
        const siblings = childrenMap.get(f.parent_folder_id) || [];
        siblings.push(f);
        childrenMap.set(f.parent_folder_id, siblings);
      }
    }
    const walk = (items: FolderType[], depth: number) => {
      for (const item of items) {
        result.push({ folder: item, depth });
        const children = childrenMap.get(item.id);
        if (children) walk(children, depth + 1);
      }
    };
    walk(roots, 0);
    return result;
  };

  const getBackUrl = () => {
    if (formData.folder_id) {
      return `/templates?folder=${getFolderUrlPath(formData.folder_id)}`;
    }
    return "/templates";
  };

  useEffect(() => {
    loadData();
  }, [id]);

  const loadData = async () => {
    try {
      setLoading(true);
      const foldersPromise = getFolders(apiKey);
      const layoutsPromise = getLayouts(apiKey);

      if (isEditMode) {
        const [templateData, foldersData, layoutsData] = await Promise.all([
          getTemplateById(parseInt(id!), apiKey),
          foldersPromise,
          layoutsPromise,
        ]);

        setTemplate(templateData);
        subjectTouchedRef.current = true;
        setFormData({
          name: templateData.name,
          trigger: templateData.trigger,
          channel: templateData.channel || "email",
          subject: templateData.subject || "",
          body: templateData.body,
          body_format: templateData.body_format || "html",
          preview: templateData.preview || "",
          folder_id: templateData.folder_id,
          layout_id: templateData.layout_id,
        });
        setFolders(foldersData);
        setLayouts(layoutsData);
      } else {
        const [foldersData, layoutsData] = await Promise.all([
          foldersPromise,
          layoutsPromise,
        ]);
        setFolders(foldersData);
        setLayouts(layoutsData);
      }
    } catch (error) {
      toast.error("Failed to load template data");
      console.error(error);
    } finally {
      setLoading(false);
    }
  };

  const handleSave = async () => {
    if (!formData.name.trim() || !formData.trigger.trim() || !formData.body.trim()) {
      toast.error("Please fill in all required fields");
      return;
    }

    try {
      setSaving(true);

      const autoPreview =
        channelDef.hasPreview && !formData.preview.trim()
          ? generatePreviewFromBody(formData.body)
          : formData.preview || undefined;

      const templateData = {
        name: formData.name,
        trigger: formData.trigger,
        channel: formData.channel,
        subject: channelDef.hasSubject ? formData.subject || undefined : undefined,
        body: formData.body,
        body_format: formData.body_format,
        preview: channelDef.hasPreview ? autoPreview : undefined,
        folder_id: formData.folder_id,
        layout_id: channelDef.hasLayout ? formData.layout_id : undefined,
      };

      if (isEditMode && template) {
        await updateTemplate(template.id, templateData, apiKey);
        toast.success("Template updated successfully");
      } else {
        await createTemplate(templateData, apiKey);
        toast.success("Template created successfully");
        navigate(getBackUrl());
      }
    } catch (error) {
      toast.error(`Failed to ${isEditMode ? "update" : "create"} template`);
      console.error(error);
    } finally {
      setSaving(false);
    }
  };

  const handleInputChange = (field: string, value: string | number | undefined) => {
    setFormData((prev) => {
      const next = { ...prev, [field]: value };

      // Prefill subject from name when creating, if subject hasn't been manually touched
      if (field === "name" && isNew && !subjectTouchedRef.current) {
        next.subject = value as string;
      }

      return next;
    });
  };

  const handleChannelChange = (channel: TemplateChannel) => {
    setFormData((prev) => {
      const def = CHANNEL_CONFIG[channel];
      return {
        ...prev,
        channel,
        // Clear fields not supported by the new channel
        subject: def.hasSubject ? prev.subject : "",
        preview: def.hasPreview ? prev.preview : "",
        layout_id: def.hasLayout ? prev.layout_id : undefined,
      };
    });
  };

  const handleSubjectChange = (value: string) => {
    subjectTouchedRef.current = true;
    handleInputChange("subject", value);
  };

  const onEmojiClick = (emojiData: EmojiClickData) => {
    const input = subjectInputRef.current;
    const emoji = emojiData.emoji;
    if (input) {
      const start = input.selectionStart ?? formData.subject.length;
      const end = input.selectionEnd ?? start;
      const newValue =
        formData.subject.slice(0, start) + emoji + formData.subject.slice(end);
      handleSubjectChange(newValue);
      requestAnimationFrame(() => {
        const pos = start + emoji.length;
        input.setSelectionRange(pos, pos);
        input.focus();
      });
    } else {
      handleSubjectChange(formData.subject + emoji);
    }
    setEmojiPickerOpen(false);
  };

  // Auto-generate preview from template body (strip HTML & Liquid tags, truncate)
  const generatePreviewFromBody = (html: string): string => {
    const text = html
      .replace(/<[^>]+>/g, " ")
      .replace(/\{\{[^}]*\}\}/g, "")
      .replace(/\{%[^%]*%\}/g, "")
      .replace(/&nbsp;/gi, " ")
      .replace(/&amp;/gi, "&")
      .replace(/&lt;/gi, "<")
      .replace(/&gt;/gi, ">")
      .replace(/\s+/g, " ")
      .trim();
    return text.length > 150 ? text.slice(0, 147) + "..." : text;
  };

  // Create folder inline
  const handleCreateFolder = async () => {
    if (!newFolderName.trim()) return;
    try {
      setCreatingFolder(true);
      const folder = await createFolderApi({ name: newFolderName }, apiKey);
      setFolders((prev) => [...prev, folder]);
      handleInputChange("folder_id", folder.id);
      setNewFolderName("");
      setCreateFolderOpen(false);
      toast.success("Folder created");
    } catch {
      toast.error("Failed to create folder");
    } finally {
      setCreatingFolder(false);
    }
  };

  const renderPreview = () => {
    if (!formData.body) {
      return <div className="p-4 text-muted-foreground">No content to preview</div>;
    }

    try {
      let preview = formData.body;

      // Replace Liquid variables BEFORE markdown transformation (matches backend order)
      preview = preview.replace(/\{\{\s*user\.name\s*\}\}/g, "John Doe");
      preview = preview.replace(/\{\{\s*user\.email\s*\}\}/g, "john@example.com");
      preview = preview.replace(/\{\{\s*company\.name\s*\}\}/g, "Acme Corp");
      // Replace any remaining Liquid variables with their variable name as placeholder
      preview = preview.replace(/\{\{\s*([\w.]+)\s*\}\}/g, (_, name) => name);

      // If markdown mode, transform using layout transformers
      const selectedLayout = layouts.find((l) => l.id === formData.layout_id);
      if (formData.body_format === "markdown" && channelDef.hasLayout) {
        const transformers = selectedLayout?.transformers || {};
        preview = transformMarkdown(preview, transformers);
      }

      // Wrap in layout if one is selected (email only)
      if (selectedLayout && channelDef.hasLayout) {
        const previewText =
          formData.preview.trim() || generatePreviewFromBody(formData.body);
        let layoutHtml = selectedLayout.body;
        layoutHtml = layoutHtml.replace(/\{\{\s*content\s*\}\}/g, preview);
        layoutHtml = layoutHtml.replace(/\{\{\s*preview\s*\}\}/g, previewText);
        layoutHtml = layoutHtml.replace(/\{\{\s*company\.name\s*\}\}/g, "Acme Corp");
        preview = layoutHtml;
      }

      // For plaintext channels, wrap in <pre>
      if (channelDef.editorLanguage === "plaintext") {
        return <PlaintextPreview text={preview} />;
      }

      return <PreviewFrame html={preview} className="w-full border-0 min-h-[400px]" />;
    } catch (error) {
      return (
        <div className="p-4 text-destructive">Preview error: {String(error)}</div>
      );
    }
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
            <Skeleton className="h-64" />
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
          <Button variant="ghost" size="sm" onClick={() => navigate(getBackUrl())}>
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div>
            <h1 className="page-heading flex items-center gap-3">
              <ChannelTypeIcon type={formData.channel} size={22} />
              {isEditMode ? `Edit ${CHANNEL_CONFIG[formData.channel].name} Template` : "Create Template"}
            </h1>
            {isEditMode && template && (
              <div className="flex items-center gap-2">
                <p className="page-subtitle">Editing: {template.name}</p>
                {currentFolder && (
                  <span className="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-md border text-xs text-muted-foreground">
                    <Folder className="h-3 w-3 text-amber-500 fill-amber-100" />
                    {currentFolder.name}
                  </span>
                )}
              </div>
            )}
          </div>
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          {isEditMode && template && (
            <Button
              variant="outline"
              onClick={() => {
                const params = new URLSearchParams({
                  template_id: String(template.id),
                  channel: formData.channel,
                });
                navigate(`/messages/compose?${params.toString()}`);
              }}
            >
              <SendHorizonal className="h-4 w-4 mr-2" />
              Send Test
            </Button>
          )}
          <Button onClick={handleSave} disabled={saving}>
            <Save className="h-4 w-4 mr-2" />
            {saving ? "Saving..." : "Save Template"}
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {/* Editor Panel */}
        <div className="space-y-6">
          {/* Channel Selection - only show for new templates */}
          {!isEditMode && (
            <Card>
              <CardHeader>
                <CardTitle>Channel</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="grid grid-cols-2 md:grid-cols-4 gap-2">
                  {(Object.keys(CHANNEL_CONFIG) as Channel[]).map((channel) => (
                    <Button
                      key={channel}
                      variant={formData.channel === channel ? "default" : "outline"}
                      onClick={() => handleChannelChange(channel)}
                      className="flex items-center gap-2 justify-start h-auto p-3"
                    >
                      <ChannelTypeIcon type={channel} size={18} />
                      <span>{CHANNEL_CONFIG[channel].name}</span>
                    </Button>
                  ))}
                </div>
              </CardContent>
            </Card>
          )}

          {/* Basic Information */}
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <FileText className="h-5 w-5" />
                Template Information
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
                <div>
                  <Label htmlFor="name">Name *</Label>
                  <Input
                    id="name"
                    value={formData.name}
                    onChange={(e) => handleInputChange("name", e.target.value)}
                    placeholder="Welcome Email"
                  />
                </div>

                <div>
                  <Label htmlFor="trigger">Trigger *</Label>
                  <Input
                    id="trigger"
                    value={formData.trigger}
                    onChange={(e) => handleInputChange("trigger", e.target.value)}
                    placeholder="user.welcome"
                  />
                </div>

                <div>
                  <Label htmlFor="folder">Folder</Label>
                  <Select
                    value={formData.folder_id?.toString()}
                    onValueChange={(value) => {
                      if (value === "__new__") {
                        setCreateFolderOpen(true);
                      } else {
                        handleInputChange(
                          "folder_id",
                          value === "none" ? undefined : parseInt(value)
                        );
                      }
                    }}
                  >
                    <SelectTrigger>
                      <SelectValue placeholder="Select folder" />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="none">No folder</SelectItem>
                      {getFolderTree().map(({ folder, depth }) => (
                        <SelectItem key={folder.id} value={folder.id.toString()}>
                          <div className={`flex items-center gap-2 ${depth > 0 ? `pl-${depth * 4}` : ""}`}>
                            <Folder className="h-4 w-4 text-amber-500 fill-amber-100" />
                            {folder.name}
                          </div>
                        </SelectItem>
                      ))}
                      <SelectItem value="__new__">
                        <div className="flex items-center gap-2 text-primary">
                          <FolderPlus className="h-4 w-4" />
                          Create new folder...
                        </div>
                      </SelectItem>
                    </SelectContent>
                  </Select>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                {channelDef.hasSubject && (
                  <div>
                    <Label htmlFor="subject">{channelDef.subjectLabel}</Label>
                    <div className="relative">
                      <Input
                        id="subject"
                        ref={subjectInputRef}
                        value={formData.subject}
                        onChange={(e) => handleSubjectChange(e.target.value)}
                        className="pr-9"
                        placeholder={
                          formData.channel === "push"
                            ? "Notification title"
                            : "Welcome to our platform!"
                        }
                      />
                      <Popover open={emojiPickerOpen} onOpenChange={setEmojiPickerOpen}>
                        <PopoverTrigger asChild>
                          <button
                            type="button"
                            className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                            title="Insert emoji"
                          >
                            <Smile className="h-4 w-4" />
                          </button>
                        </PopoverTrigger>
                        <PopoverContent align="end" className="w-auto p-0 border-0 shadow-none">
                          <EmojiPicker
                            onEmojiClick={onEmojiClick}
                            width={350}
                            height={400}
                            searchPlaceholder="Search emoji..."
                            previewConfig={{ showPreview: false }}
                          />
                        </PopoverContent>
                      </Popover>
                    </div>
                  </div>
                )}

                {channelDef.hasLayout && (
                <div>
                  <Label htmlFor="layout">Layout</Label>
                  <SearchableSelect
                    value={formData.layout_id?.toString()}
                    onValueChange={(value) => {
                      const layoutId = value === "none" ? undefined : parseInt(value);
                      handleInputChange("layout_id", layoutId);
                      if (layoutId) {
                        const layout = layouts.find((l) => l.id === layoutId);
                        const hasTransformers = layout?.transformers && Object.values(layout.transformers).some((v) => v);
                        if (hasTransformers) {
                          handleInputChange("body_format", "markdown");
                        }
                      }
                    }}
                    placeholder="Select layout (optional)"
                    searchPlaceholder="Search layouts…"
                    options={[
                      { value: "none", label: "No layout" },
                      ...layouts.map((layout) => ({
                        value: layout.id.toString(),
                        label: layout.name,
                        icon: <LayoutTemplate className="h-4 w-4 text-violet-500" />,
                      })),
                    ]}
                  />
                </div>
                )}
              </div>

              {channelDef.hasPreview && (
                <div>
                  <Label htmlFor="preview">Preview Text</Label>
                  <Input
                    id="preview"
                    value={formData.preview}
                    onChange={(e) => handleInputChange("preview", e.target.value)}
                    placeholder={
                      formData.body
                        ? generatePreviewFromBody(formData.body)
                        : "Short text shown in inbox preview (Gmail, Outlook, etc.)"
                    }
                  />
                  <p className="text-xs text-muted-foreground mt-1">
                    {formData.preview.trim()
                      ? "Appears next to the subject in email clients. Supports Liquid variables."
                      : "Leave empty to auto-generate from template body."}
                  </p>
                </div>
              )}

            </CardContent>
          </Card>

          {/* Template Body Editor */}
          <Card className="flex-1">
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Code className="h-5 w-5" />
                Template Body *
                {channelDef.maxLength && (
                  <span className="text-sm font-normal text-muted-foreground ml-auto">
                    {formData.body.length}/{channelDef.maxLength}
                  </span>
                )}
                {channelDef.hasLayout && (() => {
                  const selectedLayout = layouts.find((l) => l.id === formData.layout_id);
                  const layoutHasTransformers = selectedLayout?.transformers && Object.values(selectedLayout.transformers).some((v) => v);
                  return (
                    <div className="ml-auto flex items-center gap-2">
                      <Label
                        htmlFor="markdown-toggle"
                        className={`text-sm font-normal cursor-pointer ${layoutHasTransformers ? "text-muted-foreground/60" : "text-muted-foreground"}`}
                      >
                        Markdown
                      </Label>
                      <Switch
                        id="markdown-toggle"
                        checked={formData.body_format === "markdown"}
                        disabled={!!layoutHasTransformers}
                        onCheckedChange={(checked) =>
                          handleInputChange(
                            "body_format",
                            checked ? "markdown" : "html"
                          )
                        }
                      />
                    </div>
                  );
                })()}
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="border rounded-md overflow-hidden">
                <Editor
                  height="400px"
                  language={
                    formData.body_format === "markdown"
                      ? "markdown"
                      : channelDef.editorLanguage
                  }
                  value={formData.body}
                  onChange={(value) => handleInputChange("body", value || "")}
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
                {formData.body_format === "markdown" ? (
                  <>
                    <p className="text-sm text-muted-foreground mb-2">
                      <strong>Markdown Mode</strong>: write simple markdown, the layout's transformers convert it to styled email HTML.
                    </p>
                    <div className="grid grid-cols-2 gap-2 text-xs text-muted-foreground">
                      <code># Heading</code>
                      <code>**bold text**</code>
                      <code>[Link](url)</code>
                      <code>*italic text*</code>
                      <code>![Image](url)</code>
                      <code>{"{{ user.name }}"}</code>
                    </div>
                  </>
                ) : (
                  <>
                    <p className="text-sm text-muted-foreground mb-2">
                      <strong>Available Variables:</strong>
                    </p>
                    <div className="grid grid-cols-2 gap-2 text-xs">
                      <code>{"{{ user.name }}"}</code>
                      <code>{"{{ user.email }}"}</code>
                      <code>{"{{ company.name }}"}</code>
                      <code>{"{{ custom.variable }}"}</code>
                    </div>
                  </>
                )}
                <button
                  type="button"
                  className="text-xs text-primary hover:text-primary/80 underline mt-4 block"
                  onClick={() => handleInputChange("body", "")}
                >
                  Clear body
                </button>
              </div>

              {channelDef.maxLength && formData.body.length > channelDef.maxLength && (
                <p className="text-sm text-yellow-600 mt-2">
                  Messages over {channelDef.maxLength} characters may be split into
                  multiple messages.
                </p>
              )}
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
                <TabsList className="grid w-full grid-cols-2">
                  <TabsTrigger value="rendered">Rendered</TabsTrigger>
                  <TabsTrigger value="source">
                    {channelDef.editorLanguage === "html" ? "HTML Source" : "Source"}
                  </TabsTrigger>
                </TabsList>

                <TabsContent value="rendered" className="mt-4">
                  <div className="border rounded-md min-h-[400px] bg-card">
                    {renderPreview()}
                  </div>
                </TabsContent>

                <TabsContent value="source" className="mt-4">
                  <div className="border rounded-md overflow-hidden">
                    <Editor
                      height="400px"
                      language="html"
                      value={(() => {
                        if (formData.body_format === "markdown" && channelDef.hasLayout) {
                          const sel = layouts.find((l) => l.id === formData.layout_id);
                          return transformMarkdown(
                            formData.body,
                            sel?.transformers || {}
                          );
                        }
                        return formData.body;
                      })()}
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

      {/* Create Folder Dialog */}
      <Dialog open={createFolderOpen} onOpenChange={setCreateFolderOpen}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Create New Folder</DialogTitle>
            <DialogDescription>
              Create a folder to organize your templates.
            </DialogDescription>
          </DialogHeader>
          <div className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="newFolderName">Folder Name</Label>
              <Input
                id="newFolderName"
                value={newFolderName}
                onChange={(e) => setNewFolderName(e.target.value)}
                onKeyDown={(e) => e.key === "Enter" && handleCreateFolder()}
                placeholder="e.g. Marketing"
                autoFocus
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCreateFolderOpen(false)}>
              Cancel
            </Button>
            <Button
              onClick={handleCreateFolder}
              disabled={!newFolderName.trim() || creatingFolder}
            >
              {creatingFolder ? "Creating..." : "Create Folder"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}

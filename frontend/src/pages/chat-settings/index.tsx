import { useState, useEffect, useRef } from "react";
import { Button } from "../../components/ui/button";
import { Input } from "../../components/ui/input";
import { Label } from "../../components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../../components/ui/tabs";
import { Switch } from "../../components/ui/switch";
import { Textarea } from "../../components/ui/textarea";
import {
  getChatSettings,
  updateChatSettings,
  updateChatEnabled,
  uploadChatSettingsImage,
  removeChatSettingsImage,
  getConversationTags,
  createConversationTag,
  deleteConversationTag,
  getCannedResponses,
  createCannedResponse,
  deleteCannedResponse,
  ConversationTag,
  CannedResponse,
  WidgetSettings,
} from "../../api/chat-settings";
import { ColorField, ImageUploadField, WidgetPreview } from "./widget-preview";
import { useTabNavigation } from "../../hooks/useTabNavigation";
import { getTagColor } from "../../utils/tag-colors";
import { copyToClipboard } from "../../utils/clipboard";
import { Plus, Trash2, Save, Copy } from "lucide-react";
import toast from "react-hot-toast";

const VALID_TABS = ["install", "widget", "settings", "tags", "canned"] as const;

export function ChatSettingsPage() {
  const [activeTab, setActiveTab] = useTabNavigation("/admin/chat-widget", VALID_TABS);

  const [chatEnabled, setChatEnabled] = useState(false);
  const [settings, setSettings] = useState<WidgetSettings | null>(null);
  const [tags, setTags] = useState<ConversationTag[]>([]);
  const [cannedResponses, setCannedResponses] = useState<CannedResponse[]>([]);
  const [operators, setOperators] = useState<{ id: number; name: string; avatar_url: string | null }[]>([]);
  const [saving, setSaving] = useState(false);
  const [newTag, setNewTag] = useState({ name: "", color: "#6B7280", is_quick_reply: false });
  const [newCanned, setNewCanned] = useState({ shortcut: "", title: "", content: "" });
  const [newDomain, setNewDomain] = useState("");

  const logoInputRef = useRef<HTMLInputElement>(null);
  const headerBgInputRef = useRef<HTMLInputElement>(null);
  const chatBgInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    loadSettings();
    loadCannedResponses();
  }, []);

  async function loadSettings() {
    try {
      const res = await getChatSettings();
      setChatEnabled(res.data.chat_enabled);
      setSettings(res.data.widget_settings);
      setTags(res.data.tags);
      setOperators((res.data as any).operators || []);
    } catch {
      toast.error("Failed to load settings");
    }
  }

  async function loadTags() {
    try {
      const res = await getConversationTags();
      setTags(res.data.tags);
    } catch { /* ignore */ }
  }

  async function loadCannedResponses() {
    try {
      const res = await getCannedResponses();
      setCannedResponses(res.data.canned_responses);
    } catch { /* ignore */ }
  }

  async function handleSaveSettings() {
    if (!settings) return;
    setSaving(true);
    try {
      const {
        widget_key: _widget_key, embed_snippet: _embed_snippet, logo_url: _logo_url,
        header_background_image_url: _header_background_image_url, chat_background_image_url: _chat_background_image_url,
        ...editable
      } = settings as any;
      await updateChatSettings(editable);
      toast.success("Settings saved");
    } catch {
      toast.error("Failed to save settings");
    } finally {
      setSaving(false);
    }
  }

  async function handleImageUpload(field: string, file: File) {
    try {
      const res = await uploadChatSettingsImage(field, file);
      setSettings(res.data.widget_settings);
      toast.success("Image uploaded");
    } catch {
      toast.error("Failed to upload image");
    }
  }

  async function handleImageRemove(field: string) {
    try {
      const res = await removeChatSettingsImage(field);
      setSettings(res.data.widget_settings);
      toast.success("Image removed");
    } catch {
      toast.error("Failed to remove image");
    }
  }

  async function handleCreateTag() {
    if (!newTag.name.trim()) return;
    try {
      await createConversationTag({
        name: newTag.name.trim(),
        color: newTag.color,
        is_quick_reply: newTag.is_quick_reply,
      });
      setNewTag({ name: "", color: "#6B7280", is_quick_reply: false });
      loadTags();
      toast.success("Tag created");
    } catch (err: any) {
      const msg = err?.response?.data?.error || err?.message || "Failed to create tag";
      toast.error(typeof msg === "string" ? msg : JSON.stringify(msg));
    }
  }

  async function handleDeleteTag(id: number) {
    try {
      await deleteConversationTag(id);
      loadTags();
      toast.success("Tag deleted");
    } catch (err: any) {
      toast.error(err?.response?.data?.error || "Failed to delete tag");
    }
  }

  async function handleCreateCanned() {
    if (!newCanned.shortcut || !newCanned.title || !newCanned.content) return;
    try {
      await createCannedResponse(newCanned);
      setNewCanned({ shortcut: "", title: "", content: "" });
      loadCannedResponses();
      toast.success("Canned response created");
    } catch {
      toast.error("Failed to create canned response");
    }
  }

  async function handleDeleteCanned(id: number) {
    try {
      await deleteCannedResponse(id);
      loadCannedResponses();
      toast.success("Canned response deleted");
    } catch {
      toast.error("Failed to delete");
    }
  }

  if (!settings) return <div className="p-6">Loading...</div>;

  const headerColor = settings.header_color || settings.primary_color;
  const sendButtonColor = settings.send_button_color || settings.primary_color;
  const sendButtonTextColor = settings.send_button_text_color || '#ffffff';
  const headerTextColor = settings.header_text_color || settings.text_color;
  const buttonColor = settings.button_color || settings.primary_color;
  const buttonTextColor = settings.button_text_color || settings.text_color;

  return (
    <div className="p-6">
      <h1 className="page-heading text-2xl mb-6">Chat Widget</h1>

      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList>
          <TabsTrigger value="install">Install</TabsTrigger>
          {chatEnabled && <TabsTrigger value="widget">Widget</TabsTrigger>}
          {chatEnabled && <TabsTrigger value="settings">Settings</TabsTrigger>}
          {chatEnabled && <TabsTrigger value="tags">Tags</TabsTrigger>}
          {chatEnabled && <TabsTrigger value="canned">Canned Responses</TabsTrigger>}
        </TabsList>

        <TabsContent value="install" className="mt-4 space-y-8">
          {/* Enable Chat */}
          <section className="max-w-[800px]">
            <div className="flex items-center justify-between">
              <div>
                <h3 className="text-sm font-semibold text-gray-900">Enable Live Chat</h3>
                <p className="text-xs text-gray-400 mt-0.5">
                  {chatEnabled
                    ? "Your chat widget is active and accepting conversations"
                    : "Enable to start receiving live chat conversations on your website"}
                </p>
              </div>
              <Switch
                checked={chatEnabled}
                onCheckedChange={async (v) => {
                  try {
                    const res = await updateChatEnabled(v);
                    setChatEnabled(res.data.chat_enabled);
                    toast.success(v ? "Chat enabled" : "Chat disabled");
                  } catch {
                    toast.error("Failed to update");
                  }
                }}
              />
            </div>
          </section>

          {!chatEnabled ? (
            <p className="text-sm text-gray-500">
              Enable live chat to configure your widget and get an embed code.
            </p>
          ) : (
          <>
          {/* Embed Code */}
          <section className="max-w-[800px]">
            <h3 className="text-sm font-semibold text-gray-900 mb-1">Embed Code</h3>
            <p className="text-xs text-gray-400 mb-3">
              Add this snippet to your website's HTML, just before the closing{" "}
              <code className="bg-gray-100 px-1 rounded">&lt;/body&gt;</code> tag.
            </p>
            {(settings as any).embed_snippet ? (
              <div className="relative">
                <pre className="bg-gray-900 text-gray-100 text-sm p-4 pr-14 rounded-lg overflow-x-auto leading-relaxed">
                  {(settings as any).embed_snippet.trim()}
                </pre>
                <Button
                  variant="outline"
                  size="sm"
                  className="absolute top-2 right-2 bg-gray-800 border-gray-700 text-gray-300 hover:bg-gray-700 hover:text-white"
                  onClick={() => {
                    copyToClipboard((settings as any).embed_snippet.trim());
                    toast.success("Copied to clipboard");
                  }}
                >
                  <Copy className="h-3.5 w-3.5 mr-1" /> Copy
                </Button>
              </div>
            ) : (
              <p className="text-sm text-gray-500">
                Save your widget settings first to generate an embed code.
              </p>
            )}
          </section>

          {/* Allowed Domains */}
          <section className="space-y-4 max-w-[450px]">
            <div>
              <h3 className="text-sm font-semibold text-gray-900 mb-1">Allowed Domains</h3>
              <p className="text-xs text-gray-400">
                Restrict which websites can embed your chat widget. Use <code className="bg-gray-100 px-1 rounded">*</code> to allow any domain.
              </p>
            </div>
            <div className="flex items-center gap-2">
              <Input
                value={newDomain}
                onChange={(e) => setNewDomain(e.target.value)}
                placeholder="e.g. example.com"
                className="flex-1"
                onKeyDown={(e) => {
                  if (e.key === "Enter") {
                    e.preventDefault();
                    const d = newDomain.trim().toLowerCase();
                    if (!d) return;
                    const current = settings.allowed_domains || ["*"];
                    if (current.includes(d)) return;
                    const updated = current.filter((x) => x !== "*").concat(d);
                    setSettings({ ...settings, allowed_domains: updated });
                    setNewDomain("");
                  }
                }}
              />
              <Button
                variant="outline"
                size="sm"
                disabled={!newDomain.trim()}
                onClick={() => {
                  const d = newDomain.trim().toLowerCase();
                  if (!d) return;
                  const current = settings.allowed_domains || ["*"];
                  if (current.includes(d)) return;
                  const updated = current.filter((x) => x !== "*").concat(d);
                  setSettings({ ...settings, allowed_domains: updated });
                  setNewDomain("");
                }}
              >
                <Plus className="h-4 w-4 mr-1" /> Add
              </Button>
            </div>
            <div className="space-y-1.5">
              {(settings.allowed_domains || ["*"]).map((domain) => (
                <div
                  key={domain}
                  className="flex items-center justify-between px-3 py-1.5 bg-gray-50 rounded text-sm"
                >
                  <span className="font-mono text-xs">{domain}</span>
                  <button
                    onClick={() => {
                      const updated = (settings.allowed_domains || []).filter((d) => d !== domain);
                      setSettings({
                        ...settings,
                        allowed_domains: updated.length === 0 ? ["*"] : updated,
                      });
                    }}
                    className="text-red-400 hover:text-red-600"
                    title="Remove"
                  >
                    <Trash2 className="h-3.5 w-3.5" />
                  </button>
                </div>
              ))}
            </div>
            <Button onClick={handleSaveSettings} disabled={saving}>
              <Save className="h-4 w-4 mr-1" /> {saving ? "Saving..." : "Save Domains"}
            </Button>
            {!(settings.allowed_domains || ["*"]).includes("*") && (
              <button
                className="text-xs text-gray-400 hover:text-gray-600 mt-2"
                onClick={() => setSettings({ ...settings, allowed_domains: ["*"] })}
              >
                Reset to allow all domains
              </button>
            )}
          </section>
          </>
          )}
        </TabsContent>

        <TabsContent value="widget" className="mt-4">
          <div className="flex flex-col md:flex-row gap-8">
            <div className="flex-1 space-y-0">

              {/* ── General ── */}
              <section className="pb-6">
                <h3 className="text-sm font-semibold text-gray-900 mb-4">General</h3>
                <div>
                  <Label>Widget Title</Label>
                  <Input
                    value={settings.title || ""}
                    onChange={(e) => setSettings({ ...settings, title: e.target.value })}
                    placeholder="Chat with us"
                    className="mt-1 max-w-sm"
                  />
                </div>
              </section>

              <hr className="border-gray-100" />

              {/* ── Branding ── */}
              <section className="py-6">
                <h3 className="text-sm font-semibold text-gray-900 mb-1">Branding</h3>
                <p className="text-xs text-gray-400 mb-4">Logo and background images for your chat widget</p>
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  <ImageUploadField
                    label="Logo"
                    description="Shown in the chat header"
                    currentUrl={settings.logo_url}
                    inputRef={logoInputRef}
                    onUpload={(f) => handleImageUpload("logo", f)}
                    onRemove={() => handleImageRemove("logo")}
                  />
                  <ImageUploadField
                    label="Header Background"
                    description="Background image for the header"
                    currentUrl={settings.header_background_image_url}
                    inputRef={headerBgInputRef}
                    onUpload={(f) => handleImageUpload("header_background_image", f)}
                    onRemove={() => handleImageRemove("header_background_image")}
                  />
                  <ImageUploadField
                    label="Chat Background"
                    description="Background image for the chat area"
                    currentUrl={settings.chat_background_image_url}
                    inputRef={chatBgInputRef}
                    onUpload={(f) => handleImageUpload("chat_background_image", f)}
                    onRemove={() => handleImageRemove("chat_background_image")}
                  />
                </div>
              </section>

              <hr className="border-gray-100" />

              {/* ── Colors ── */}
              <section className="py-6 space-y-5">
                <div>
                  <h3 className="text-sm font-semibold text-gray-900 mb-1">Colors</h3>
                  <p className="text-xs text-gray-400 mb-4">Customize the look and feel of your chat widget</p>
                </div>

                {/* Theme */}
                <div>
                  <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">Theme</p>
                  <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
                    <ColorField label="Primary" value={settings.primary_color} onChange={(v) => setSettings({ ...settings, primary_color: v })} />
                    <ColorField label="Secondary" value={settings.secondary_color} onChange={(v) => setSettings({ ...settings, secondary_color: v })} />
                    <ColorField label="Text" value={settings.text_color} onChange={(v) => setSettings({ ...settings, text_color: v })} />
                  </div>
                </div>

                {/* Chat Window */}
                <div>
                  <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">Chat Window</p>
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                    <ColorField label="Header BG" value={headerColor} onChange={(v) => setSettings({ ...settings, header_color: v })} />
                    <ColorField label="Header Text" value={headerTextColor} onChange={(v) => setSettings({ ...settings, header_text_color: v })} />
                    <ColorField label="Send Button" value={sendButtonColor} onChange={(v) => setSettings({ ...settings, send_button_color: v })} />
                    <ColorField label="Send Text" value={sendButtonTextColor} onChange={(v) => setSettings({ ...settings, send_button_text_color: v })} />
                  </div>
                </div>

                {/* Chat Bubble */}
                <div>
                  <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">Chat Bubble</p>
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
                    <ColorField label="Bubble Color" value={buttonColor} onChange={(v) => setSettings({ ...settings, button_color: v })} />
                    <ColorField label="Icon Color" value={buttonTextColor} onChange={(v) => setSettings({ ...settings, button_text_color: v })} />
                  </div>
                </div>
              </section>

              <hr className="border-gray-100" />

              <div className="pt-6">
                <Button onClick={handleSaveSettings} disabled={saving}>
                  <Save className="h-4 w-4 mr-1" /> {saving ? "Saving..." : "Save Settings"}
                </Button>
              </div>
            </div>
            <div className="w-full md:w-80 shrink-0">
              <WidgetPreview
                settings={settings}
                headerColor={headerColor}
                headerTextColor={headerTextColor}
                sendButtonColor={sendButtonColor}
                sendButtonTextColor={sendButtonTextColor}
                buttonColor={buttonColor}
                buttonTextColor={buttonTextColor}
                operators={operators}
              />
            </div>
          </div>
        </TabsContent>

        <TabsContent value="settings" className="mt-4">
          <div className="flex flex-col md:flex-row gap-8">
            <div className="flex-1 space-y-0">
              {/* ── Behavior ── */}
              <section className="pb-6 space-y-4">
                <h3 className="text-sm font-semibold text-gray-900 mb-1">Behavior</h3>
                <div className="space-y-3">
                  <div className="flex items-center justify-between">
                    <div>
                      <Label>Require email before chat</Label>
                      <p className="text-xs text-gray-400">Visitors must enter their email before starting a conversation</p>
                    </div>
                    <Switch
                      checked={settings.require_email_before_chat}
                      onCheckedChange={(v) =>
                        setSettings({ ...settings, require_email_before_chat: v })
                      }
                    />
                  </div>
                  <div className="flex items-center justify-between">
                    <div>
                      <Label>Show operator avatars</Label>
                      <p className="text-xs text-gray-400">Display online operator photos in the widget</p>
                    </div>
                    <Switch
                      checked={settings.show_operator_avatars}
                      onCheckedChange={(v) =>
                        setSettings({ ...settings, show_operator_avatars: v })
                      }
                    />
                  </div>
                  <div className="flex items-center justify-between">
                    <div>
                      <Label>Show online operator count</Label>
                      <p className="text-xs text-gray-400">Show how many operators are currently available</p>
                    </div>
                    <Switch
                      checked={settings.show_operator_count}
                      onCheckedChange={(v) =>
                        setSettings({ ...settings, show_operator_count: v })
                      }
                    />
                  </div>
                </div>
                <div className="pt-1">
                  <Label>Auto-close after (hours)</Label>
                  <p className="text-xs text-gray-400 mt-0.5 mb-1.5">Automatically close inactive conversations</p>
                  <Input
                    type="number"
                    value={settings.auto_close_hours}
                    onChange={(e) =>
                      setSettings({ ...settings, auto_close_hours: Number(e.target.value) })
                    }
                    className="w-24"
                  />
                </div>
              </section>

              <hr className="border-gray-100" />

              {/* ── Messages ── */}
              <section className="py-6 space-y-4">
                <h3 className="text-sm font-semibold text-gray-900 mb-1">Messages</h3>
                <div>
                  <Label>Greeting Message</Label>
                  <p className="text-xs text-gray-400 mt-0.5 mb-1.5">Shown to visitors when they open the chat</p>
                  <Textarea
                    value={settings.greeting_message}
                    onChange={(e) =>
                      setSettings({ ...settings, greeting_message: e.target.value })
                    }
                  />
                </div>
                <div>
                  <Label>Offline Message</Label>
                  <p className="text-xs text-gray-400 mt-0.5 mb-1.5">Shown when no operators are online</p>
                  <Textarea
                    value={settings.offline_message}
                    onChange={(e) =>
                      setSettings({ ...settings, offline_message: e.target.value })
                    }
                  />
                </div>
              </section>

              <hr className="border-gray-100" />

              {/* ── Business Hours ── */}
              <section className="py-6 space-y-4">
                <h3 className="text-sm font-semibold text-gray-900 mb-1">Business Hours</h3>
              <div className="flex items-center justify-between">
                <div>
                  <Label>Enable business hours</Label>
                  <p className="text-xs text-gray-400">When enabled, visitors see the offline form outside these hours</p>
                </div>
                <Switch
                  checked={settings.business_hours_enabled}
                  onCheckedChange={(v) =>
                    setSettings({ ...settings, business_hours_enabled: v })
                  }
                />
              </div>

              <div>
                <Label>Timezone</Label>
                <Input
                  value={settings.timezone}
                  onChange={(e) => setSettings({ ...settings, timezone: e.target.value })}
                  className="mt-1 w-64"
                  placeholder="e.g. America/New_York"
                />
              </div>

              {settings.business_hours_enabled && (
                <div className="space-y-2">
                  <Label>Schedule</Label>
                  {(["mon", "tue", "wed", "thu", "fri", "sat", "sun"] as const).map((day) => {
                    const dayLabel = { mon: "Monday", tue: "Tuesday", wed: "Wednesday", thu: "Thursday", fri: "Friday", sat: "Saturday", sun: "Sunday" }[day];
                    const hours = settings.business_hours?.[day];
                    const enabled = !!hours;

                    return (
                      <div key={day} className="flex items-center gap-3 py-1.5">
                        <div className="w-24">
                          <label className="flex items-center gap-2 text-sm cursor-pointer">
                            <input
                              type="checkbox"
                              checked={enabled}
                              onChange={(e) => {
                                const bh = { ...settings.business_hours };
                                if (e.target.checked) {
                                  bh[day] = { start: "09:00", end: "17:00" };
                                } else {
                                  delete bh[day];
                                }
                                setSettings({ ...settings, business_hours: bh });
                              }}
                              className="rounded"
                            />
                            {dayLabel}
                          </label>
                        </div>
                        {enabled ? (
                          <div className="flex items-center gap-2">
                            <Input
                              type="time"
                              value={hours.start}
                              onChange={(e) => {
                                const bh = { ...settings.business_hours };
                                bh[day] = { ...bh[day], start: e.target.value };
                                setSettings({ ...settings, business_hours: bh });
                              }}
                              className="w-32 h-8 text-sm"
                            />
                            <span className="text-xs text-gray-400">to</span>
                            <Input
                              type="time"
                              value={hours.end}
                              onChange={(e) => {
                                const bh = { ...settings.business_hours };
                                bh[day] = { ...bh[day], end: e.target.value };
                                setSettings({ ...settings, business_hours: bh });
                              }}
                              className="w-32 h-8 text-sm"
                            />
                          </div>
                        ) : (
                          <span className="text-xs text-gray-400">Closed</span>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
              </section>

              <hr className="border-gray-100" />

              <div className="pt-6">
                <Button onClick={handleSaveSettings} disabled={saving}>
                  <Save className="h-4 w-4 mr-1" /> {saving ? "Saving..." : "Save Settings"}
                </Button>
              </div>
            </div>
            <div className="w-full md:w-80 shrink-0">
              <WidgetPreview
                settings={settings}
                headerColor={headerColor}
                headerTextColor={headerTextColor}
                sendButtonColor={sendButtonColor}
                sendButtonTextColor={sendButtonTextColor}
                buttonColor={buttonColor}
                buttonTextColor={buttonTextColor}
                operators={operators}
              />
            </div>
          </div>
        </TabsContent>

        <TabsContent value="tags" className="mt-4">
          <div className="space-y-4">
            <div className="max-w-[450px] space-y-3">
              <div>
                <Label>Tag name</Label>
                <Input
                  value={newTag.name}
                  onChange={(e) => setNewTag({ ...newTag, name: e.target.value })}
                  placeholder="e.g. Billing"
                  className="mt-1"
                />
              </div>
              <div className="flex items-center gap-3">
                <div>
                  <Label>Color</Label>
                  <input
                    type="color"
                    value={newTag.color}
                    onChange={(e) => setNewTag({ ...newTag, color: e.target.value })}
                    className="mt-1 block w-9 h-9 rounded border border-gray-200 cursor-pointer p-0.5"
                  />
                </div>
                <label className="flex items-center gap-1.5 text-sm mt-5">
                  <input
                    type="checkbox"
                    checked={newTag.is_quick_reply}
                    onChange={(e) => setNewTag({ ...newTag, is_quick_reply: e.target.checked })}
                    className="rounded"
                  />
                  Quick reply
                </label>
              </div>
              <Button onClick={handleCreateTag} disabled={!newTag.name.trim()} size="sm">
                <Plus className="h-4 w-4 mr-1" /> Add
              </Button>
            </div>

            <div className="space-y-2 max-w-[450px]">
              {tags.map((tag) => (
                <div
                  key={tag.id}
                  className="flex items-center justify-between p-2 bg-gray-50 rounded"
                >
                  <div className="flex items-center gap-2">
                    <div
                      className="w-4 h-4 rounded"
                      style={{ backgroundColor: getTagColor(tag.name) }}
                    />
                    <span className="text-sm">{tag.name}</span>
                    {tag.is_quick_reply && (
                      <span className="text-xs bg-blue-100 text-blue-700 px-1.5 rounded">
                        quick reply
                      </span>
                    )}
                  </div>
                  <button
                    onClick={() => handleDeleteTag(tag.id)}
                    className="text-red-500 hover:text-red-700"
                  >
                    <Trash2 className="h-4 w-4" />
                  </button>
                </div>
              ))}
            </div>
          </div>
        </TabsContent>

        <TabsContent value="canned" className="mt-4">
          <div className="space-y-4">
            <div className="max-w-[450px] space-y-3">
              <div>
                <Label>Shortcut</Label>
                <Input
                  value={newCanned.shortcut}
                  onChange={(e) => setNewCanned({ ...newCanned, shortcut: e.target.value })}
                  placeholder="/greeting"
                  className="mt-1"
                />
              </div>
              <div>
                <Label>Title</Label>
                <Input
                  value={newCanned.title}
                  onChange={(e) => setNewCanned({ ...newCanned, title: e.target.value })}
                  placeholder="Welcome greeting"
                  className="mt-1"
                />
              </div>
              {newCanned.shortcut && (
                <div>
                  <Label>Content</Label>
                  <Textarea
                    value={newCanned.content}
                    onChange={(e) => setNewCanned({ ...newCanned, content: e.target.value })}
                    placeholder="Response content..."
                    className="mt-1"
                  />
                </div>
              )}
              <Button onClick={handleCreateCanned} size="sm">
                <Plus className="h-4 w-4 mr-1" /> Add
              </Button>
            </div>

            <div className="space-y-2 max-w-[450px]">
              {cannedResponses.map((cr) => (
                <div key={cr.id} className="p-3 bg-gray-50 rounded">
                  <div className="flex justify-between items-start">
                    <div>
                      <code className="text-xs bg-gray-200 px-1 rounded">{cr.shortcut}</code>
                      <span className="text-sm font-medium ml-2">{cr.title}</span>
                    </div>
                    <button
                      onClick={() => handleDeleteCanned(cr.id)}
                      className="text-red-500 hover:text-red-700"
                    >
                      <Trash2 className="h-4 w-4" />
                    </button>
                  </div>
                  <p className="text-xs text-gray-500 mt-1">{cr.content}</p>
                </div>
              ))}
            </div>
          </div>
        </TabsContent>

      </Tabs>
    </div>
  );
}

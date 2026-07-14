import { useState, useEffect, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import { Button } from "../../components/ui/button";
import { Input } from "../../components/ui/input";
import { Label } from "../../components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "../../components/ui/tabs";
import { Switch } from "../../components/ui/switch";
import { Textarea } from "../../components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "../../components/ui/card";
import { Badge } from "../../components/ui/badge";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "../../components/ui/select";
import { SearchableSelect } from "@/components/ui/searchable-select";
import {
  getMailboxes,
  createMailbox,
  updateMailbox,
  deleteMailbox,
  testMailboxConnection,
  getMailboxOauthUrl,
  Mailbox,
  MailboxProvider,
} from "../../api/mailboxes";

const PROVIDER_LABELS: Record<MailboxProvider, string> = {
  imap: "IMAP",
  gmail: "Gmail",
  office365: "Office 365",
};
import { getHelpdeskStats, HelpdeskStats } from "../../api/helpdesk";
import { useTabNavigation } from "../../hooks/useTabNavigation";
import {
  Plus,
  Trash2,
  Save,
  Mail,
  CheckCircle2,
  Clock,
  AlertCircle,
  Loader2,
  Plug,
} from "lucide-react";
import toast from "react-hot-toast";
import { HELPDESK_EVENT_LABELS } from "@/lib/labels";

const VALID_TABS = ["dashboard", "mailboxes", "settings"] as const;

export function HelpdeskPage() {
  const [activeTab, setActiveTab] = useTabNavigation("/admin/help-desk", VALID_TABS);
  const [mailboxes, setMailboxes] = useState<Mailbox[]>([]);
  const [mailboxesLoading, setMailboxesLoading] = useState(true);

  const loadMailboxes = useCallback(async () => {
    try {
      const res = await getMailboxes();
      setMailboxes(res.data.mailboxes);
    } catch {
      toast.error("Failed to load mailboxes");
    } finally {
      setMailboxesLoading(false);
    }
  }, []);

  useEffect(() => {
    loadMailboxes();
  }, [loadMailboxes]);

  return (
    <div className="p-6 space-y-6 bg-background min-h-screen">
      <div>
        <h1 className="page-heading">Help Desk</h1>
        <p className="page-subtitle">Manage email tickets, mailboxes, and notification settings</p>
      </div>

      <Tabs value={activeTab} onValueChange={setActiveTab}>
        <TabsList>
          <TabsTrigger value="dashboard">Dashboard</TabsTrigger>
          <TabsTrigger value="mailboxes">Mailboxes</TabsTrigger>
          <TabsTrigger value="settings">Settings</TabsTrigger>
        </TabsList>

        <TabsContent value="dashboard" className="mt-6">
          <DashboardTab />
        </TabsContent>
        <TabsContent value="mailboxes" className="mt-6">
          <MailboxesTab mailboxes={mailboxes} loading={mailboxesLoading} onReload={loadMailboxes} />
        </TabsContent>
        <TabsContent value="settings" className="mt-6">
          <SettingsTab mailboxes={mailboxes} loading={mailboxesLoading} />
        </TabsContent>
      </Tabs>
    </div>
  );
}

/* ── Dashboard Tab ─────────────────────────────────────────────────────── */

function DashboardTab() {
  const navigate = useNavigate();
  const [stats, setStats] = useState<HelpdeskStats | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getHelpdeskStats()
      .then((res) => setStats(res.data))
      .catch(() => toast.error("Failed to load dashboard stats"))
      .finally(() => setLoading(false));
  }, []);

  if (loading) {
    return (
      <div className="space-y-6 animate-pulse">
        <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
          {[...Array(4)].map((_, i) => (
            <Card key={i} className="card-shadow bg-card">
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <div className="h-4 w-24 bg-muted/50 rounded" />
                <div className="w-8 h-8 bg-muted/30 rounded-lg" />
              </CardHeader>
              <CardContent>
                <div className="h-7 w-16 bg-muted/60 rounded mt-1" />
                <div className="h-3 w-32 bg-muted/30 rounded mt-3" />
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    );
  }

  if (!stats) return null;

  function formatDuration(seconds: number | null) {
    if (!seconds) return "\u2014";
    if (seconds < 60) return `${seconds}s`;
    if (seconds < 3600) return `${Math.round(seconds / 60)}m`;
    return `${(seconds / 3600).toFixed(1)}h`;
  }

  return (
    <div className="space-y-6">
      <div className="grid gap-6 md:grid-cols-2 lg:grid-cols-4">
        <Card className="card-shadow bg-card cursor-pointer hover:shadow-md transition-shadow" onClick={() => navigate("/inbox?source=email")}>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Open</CardTitle>
            <div className="w-8 h-8 bg-orange-100 rounded-lg flex items-center justify-center">
              <AlertCircle className="h-4 w-4 text-orange-600" />
            </div>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">{stats.open_count}</div>
            <p className="text-xs text-muted-foreground mt-1 font-mono">
              {stats.unassigned_count} unassigned
            </p>
          </CardContent>
        </Card>

        <Card className="card-shadow bg-card cursor-pointer hover:shadow-md transition-shadow" onClick={() => navigate("/inbox?source=email&assigned=unassigned")}>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Unassigned</CardTitle>
            <div className="w-8 h-8 bg-yellow-100 rounded-lg flex items-center justify-center">
              <Clock className="h-4 w-4 text-yellow-600" />
            </div>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">{stats.unassigned_count}</div>
            <p className="text-xs text-muted-foreground mt-1 font-mono">
              Awaiting assignment
            </p>
          </CardContent>
        </Card>

        <Card className="card-shadow bg-card cursor-pointer hover:shadow-md transition-shadow" onClick={() => navigate("/inbox?source=email&status=resolved")}>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Resolved</CardTitle>
            <div className="w-8 h-8 bg-green-100 rounded-lg flex items-center justify-center">
              <CheckCircle2 className="h-4 w-4 text-green-600" />
            </div>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">{stats.resolved_count}</div>
            <p className="text-xs text-muted-foreground mt-1 font-mono">
              {stats.closed_count} closed
            </p>
          </CardContent>
        </Card>

        <Card className="card-shadow bg-card cursor-pointer hover:shadow-md transition-shadow" onClick={() => navigate("/inbox?source=email")}>
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">This Week</CardTitle>
            <div className="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center">
              <Mail className="h-4 w-4 text-blue-600" />
            </div>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">{stats.tickets_this_week}</div>
            <p className="text-xs text-muted-foreground mt-1 font-mono">
              {stats.tickets_today} today
            </p>
          </CardContent>
        </Card>
      </div>

      <div className="grid gap-6 md:grid-cols-2">
        <Card className="card-shadow bg-card">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Avg First Response</CardTitle>
            <div className="w-8 h-8 bg-accent rounded-lg flex items-center justify-center">
              <Clock className="h-4 w-4 text-primary" />
            </div>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">
              {formatDuration(stats.avg_first_response_seconds)}
            </div>
            <p className="text-xs text-muted-foreground mt-1 font-mono">
              Time to first operator reply
            </p>
          </CardContent>
        </Card>

        <Card className="card-shadow bg-card">
          <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
            <CardTitle className="text-sm font-medium text-muted-foreground">Avg Resolution</CardTitle>
            <div className="w-8 h-8 bg-muted rounded-lg flex items-center justify-center">
              <CheckCircle2 className="h-4 w-4 text-muted-foreground" />
            </div>
          </CardHeader>
          <CardContent>
            <div className="text-2xl font-bold text-foreground">
              {formatDuration(stats.avg_resolution_seconds)}
            </div>
            <p className="text-xs text-muted-foreground mt-1 font-mono">
              Time from creation to resolved
            </p>
          </CardContent>
        </Card>
      </div>

      {stats.per_operator.length > 0 && (
        <Card className="card-shadow bg-card">
          <CardHeader>
            <CardTitle className="text-foreground">Tickets by Operator</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b">
                  <th className="text-left px-6 py-3 text-xs font-medium text-muted-foreground uppercase tracking-wider">Operator</th>
                  <th className="text-center px-6 py-3 text-xs font-medium text-muted-foreground uppercase tracking-wider">Open</th>
                  <th className="text-center px-6 py-3 text-xs font-medium text-muted-foreground uppercase tracking-wider">Pending</th>
                  <th className="text-center px-6 py-3 text-xs font-medium text-muted-foreground uppercase tracking-wider">Resolved Today</th>
                </tr>
              </thead>
              <tbody>
                {stats.per_operator.map((op) => (
                  <tr
                    key={op.user_id}
                    className="border-b last:border-0 hover:bg-muted cursor-pointer"
                    onClick={() => navigate(`/inbox?source=email&assigned=all&q=${encodeURIComponent(op.name)}`)}
                  >
                    <td className="px-6 py-3 flex items-center gap-3">
                      {op.avatar_url ? (
                        <img src={op.avatar_url} className="h-7 w-7 rounded-full object-cover" alt={op.name} />
                      ) : (
                        <div className="h-7 w-7 rounded-full bg-muted flex items-center justify-center text-xs font-semibold">
                          {op.name?.charAt(0)?.toUpperCase()}
                        </div>
                      )}
                      <span className="font-medium text-foreground">{op.name}</span>
                    </td>
                    <td className="px-6 py-3 text-center font-mono">{op.open_count}</td>
                    <td className="px-6 py-3 text-center font-mono">{op.pending_count}</td>
                    <td className="px-6 py-3 text-center font-mono">{op.resolved_today}</td>
                  </tr>
                ))}
              </tbody>
            </table>
            </div>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

/* ── Mailboxes Tab ─────────────────────────────────────────────────────── */

function MailboxesTab({ mailboxes, loading, onReload }: { mailboxes: Mailbox[]; loading: boolean; onReload: () => void }) {
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Mailbox | null>(null);
  const [form, setForm] = useState({
    name: "",
    email_address: "",
    provider: "imap" as MailboxProvider,
    ticket_prefix: "",
    auto_assign: true,
    config: {
      host: "",
      port: "993",
      username: "",
      password: "",
      ssl: "true",
      folder: "INBOX",
    },
  });
  const [saving, setSaving] = useState(false);
  const [testing, setTesting] = useState<number | null>(null);
  const [connecting, setConnecting] = useState<number | null>(null);

  function startCreate() {
    setEditing(null);
    setForm({
      name: "",
      email_address: "",
      provider: "imap",
      ticket_prefix: "",
      auto_assign: true,
      config: { host: "", port: "993", username: "", password: "", ssl: "true", folder: "INBOX" },
    });
    setShowForm(true);
  }

  function startEdit(m: Mailbox) {
    setEditing(m);
    setForm({
      name: m.name,
      email_address: m.email_address,
      provider: m.provider,
      ticket_prefix: m.ticket_prefix,
      auto_assign: m.auto_assign,
      config: { host: "", port: "993", username: "", password: "", ssl: "true", folder: "INBOX" },
    });
    setShowForm(true);
  }

  async function handleSave() {
    setSaving(true);
    try {
      // OAuth providers (gmail/office365) carry no credentials in config — the
      // user authorizes via the Connect button after the mailbox is created.
      const configToSend: Record<string, string> = {};
      if (form.provider === "imap") {
        configToSend.host = form.config.host;
        configToSend.port = form.config.port;
        configToSend.username = form.config.username;
        configToSend.password = form.config.password;
        configToSend.ssl = form.config.ssl;
        configToSend.folder = form.config.folder;
      }

      const payload = {
        name: form.name,
        email_address: form.email_address,
        provider: form.provider,
        ticket_prefix: form.ticket_prefix,
        auto_assign: form.auto_assign,
        config: configToSend,
      };

      if (editing) {
        await updateMailbox(editing.id, payload);
        toast.success("Mailbox updated");
      } else {
        await createMailbox(payload);
        toast.success("Mailbox created");
      }
      setShowForm(false);
      onReload();
    } catch (e: any) {
      toast.error(e.response?.data?.error || "Failed to save mailbox");
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id: number) {
    if (!confirm("Delete this mailbox? All associated email threads will also be removed.")) return;
    try {
      await deleteMailbox(id);
      toast.success("Mailbox deleted");
      onReload();
    } catch {
      toast.error("Failed to delete mailbox");
    }
  }

  // Surface the OAuth result after the provider redirects back to /helpdesk.
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const connected = params.get("connected");
    const error = params.get("error");
    if (connected) {
      toast.success(`${PROVIDER_LABELS[connected as MailboxProvider] || "Mailbox"} connected`);
    } else if (error) {
      toast.error(error === "oauth_failed" ? "Connection failed, please try again" : `Connection error: ${error}`);
    }
    if (connected || error) {
      params.delete("connected");
      params.delete("error");
      const qs = params.toString();
      window.history.replaceState({}, "", `${window.location.pathname}${qs ? `?${qs}` : ""}`);
      if (connected) onReload();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function handleConnect(id: number) {
    setConnecting(id);
    try {
      const res = await getMailboxOauthUrl(id);
      window.location.href = res.data.url;
    } catch (e: any) {
      toast.error(e.response?.data?.error || "Could not start authorization");
      setConnecting(null);
    }
  }

  async function handleTestConnection(id: number) {
    setTesting(id);
    try {
      const res = await testMailboxConnection(id);
      if (res.data.success) {
        toast.success("Connection successful!");
      } else {
        toast.error(res.data.error || "Connection failed");
      }
    } catch (e: any) {
      toast.error(e.response?.data?.error || "Connection failed");
    } finally {
      setTesting(null);
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <p className="text-sm text-muted-foreground">
          Configure email inboxes to receive support tickets.
        </p>
        <Button onClick={startCreate} size="sm">
          <Plus className="h-4 w-4 mr-1" /> Add Mailbox
        </Button>
      </div>

      {showForm && (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">
              {editing ? "Edit Mailbox" : "New Mailbox"}
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <Label>Name</Label>
                <Input
                  value={form.name}
                  onChange={(e) => setForm({ ...form, name: e.target.value })}
                  placeholder="Support"
                />
              </div>
              <div>
                <Label>Email Address</Label>
                <Input
                  value={form.email_address}
                  onChange={(e) => setForm({ ...form, email_address: e.target.value })}
                  placeholder="support@company.com"
                />
              </div>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
              <div>
                <Label>Provider</Label>
                <Select
                  value={form.provider}
                  onValueChange={(v) => setForm({ ...form, provider: v as MailboxProvider })}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="imap">IMAP</SelectItem>
                    <SelectItem value="gmail">Gmail</SelectItem>
                    <SelectItem value="office365">Office 365</SelectItem>
                  </SelectContent>
                </Select>
              </div>
              <div>
                <Label>Ticket Prefix</Label>
                <Input
                  value={form.ticket_prefix}
                  onChange={(e) => setForm({ ...form, ticket_prefix: e.target.value.toUpperCase() })}
                  placeholder="SUP (optional)"
                />
                <p className="text-xs text-muted-foreground mt-1">
                  Tickets will be numbered {form.ticket_prefix ? `${form.ticket_prefix}-1001` : "#1001"}
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <Switch
                checked={form.auto_assign}
                onCheckedChange={(c) => setForm({ ...form, auto_assign: c })}
              />
              <Label>Auto-assign new tickets to available operators</Label>
            </div>

            {/* Provider-specific config */}
            {form.provider === "imap" ? (
              <div className="space-y-4 border-t pt-4">
                <h3 className="text-sm font-medium">IMAP Settings</h3>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <Label>Host</Label>
                    <Input
                      value={form.config.host}
                      onChange={(e) =>
                        setForm({ ...form, config: { ...form.config, host: e.target.value } })
                      }
                      placeholder="imap.gmail.com"
                    />
                  </div>
                  <div>
                    <Label>Port</Label>
                    <Input
                      value={form.config.port}
                      onChange={(e) =>
                        setForm({ ...form, config: { ...form.config, port: e.target.value } })
                      }
                      placeholder="993"
                    />
                  </div>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <Label>Username</Label>
                    <Input
                      value={form.config.username}
                      onChange={(e) =>
                        setForm({ ...form, config: { ...form.config, username: e.target.value } })
                      }
                      placeholder="support@company.com"
                    />
                  </div>
                  <div>
                    <Label>Password</Label>
                    <Input
                      type="password"
                      value={form.config.password}
                      onChange={(e) =>
                        setForm({ ...form, config: { ...form.config, password: e.target.value } })
                      }
                    />
                  </div>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div>
                    <Label>Folder</Label>
                    <Input
                      value={form.config.folder}
                      onChange={(e) =>
                        setForm({ ...form, config: { ...form.config, folder: e.target.value } })
                      }
                      placeholder="INBOX"
                    />
                  </div>
                  <div className="flex items-center gap-2 pt-6">
                    <Switch
                      checked={form.config.ssl === "true"}
                      onCheckedChange={(c) =>
                        setForm({ ...form, config: { ...form.config, ssl: c ? "true" : "false" } })
                      }
                    />
                    <Label>Use SSL</Label>
                  </div>
                </div>
              </div>
            ) : (
              <div className="space-y-2 border-t pt-4">
                <h3 className="text-sm font-medium">{PROVIDER_LABELS[form.provider]} connection</h3>
                <p className="text-sm text-muted-foreground">
                  {editing
                    ? `Save your changes, then use Connect to authorize ${PROVIDER_LABELS[form.provider]} access.`
                    : `After creating this mailbox, use the Connect button to sign in with ${PROVIDER_LABELS[form.provider]} and grant access. New mail then arrives via cloud push.`}
                </p>
              </div>
            )}

            <div className="flex items-center gap-2 pt-2">
              <Button onClick={handleSave} disabled={saving} size="sm">
                {saving ? <Loader2 className="h-4 w-4 animate-spin mr-1" /> : <Save className="h-4 w-4 mr-1" />}
                {editing ? "Update" : "Create"}
              </Button>
              <Button variant="outline" size="sm" onClick={() => setShowForm(false)}>
                Cancel
              </Button>
            </div>
          </CardContent>
        </Card>
      )}

      {/* Mailbox list */}
      {mailboxes.length === 0 && !showForm ? (
        <Card>
          <CardContent className="py-12 text-center">
            <Mail className="h-10 w-10 mx-auto text-muted-foreground mb-3" />
            <p className="text-muted-foreground">No mailboxes configured yet.</p>
            <p className="text-sm text-muted-foreground mt-1">
              Add a mailbox to start receiving email tickets.
            </p>
          </CardContent>
        </Card>
      ) : (
        <div className="space-y-3">
          {mailboxes.map((m) => (
            <Card key={m.id}>
              <CardContent className="py-4 flex items-center justify-between flex-wrap gap-4">
                <div className="flex items-center gap-3">
                  <Mail className="h-5 w-5 text-muted-foreground" />
                  <div>
                    <div className="font-medium flex items-center gap-2 flex-wrap">
                      {m.name}
                      <Badge variant={m.active ? "default" : "secondary"}>
                        {m.active ? "Active" : "Inactive"}
                      </Badge>
                      <Badge variant="outline">{PROVIDER_LABELS[m.provider]}</Badge>
                      {m.provider !== "imap" && (
                        <Badge variant={m.connected ? "default" : "secondary"}>
                          {m.connected ? "Connected" : "Not connected"}
                        </Badge>
                      )}
                      {m.push_active && (
                        <Badge variant="outline" className="text-green-600 border-green-600/40">
                          Push active
                        </Badge>
                      )}
                    </div>
                    <div className="text-sm text-muted-foreground">
                      {m.email_address}
                      {m.ticket_prefix && (
                        <span className="ml-2">
                          Prefix: <strong>{m.ticket_prefix}</strong>
                        </span>
                      )}
                      {m.last_synced_at && (
                        <span className="ml-2">
                          Last synced: {new Date(m.last_synced_at).toLocaleString()}
                        </span>
                      )}
                    </div>
                  </div>
                </div>
                <div className="flex items-center gap-2">
                  {m.provider !== "imap" && (
                    <Button
                      variant={m.connected ? "outline" : "default"}
                      size="sm"
                      onClick={() => handleConnect(m.id)}
                      disabled={connecting === m.id}
                    >
                      {connecting === m.id ? (
                        <Loader2 className="h-4 w-4 animate-spin mr-1" />
                      ) : (
                        <Plug className="h-4 w-4 mr-1" />
                      )}
                      {m.connected ? "Reconnect" : "Connect"}
                    </Button>
                  )}
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={() => handleTestConnection(m.id)}
                    disabled={testing === m.id}
                    title="Test connection"
                  >
                    {testing === m.id ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : (
                      <Plug className="h-4 w-4" />
                    )}
                  </Button>
                  <Button variant="outline" size="sm" onClick={() => startEdit(m)}>
                    Edit
                  </Button>
                  <Button
                    variant="outline"
                    size="sm"
                    className="text-destructive"
                    onClick={() => handleDelete(m.id)}
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

/* ── Settings Tab ──────────────────────────────────────────────────────── */

function SettingsTab({ mailboxes, loading }: { mailboxes: Mailbox[]; loading: boolean }) {
  const [selectedId, setSelectedId] = useState<number | null>(null);
  const [saving, setSaving] = useState(false);

  const [notificationEvents, setNotificationEvents] = useState<Record<string, boolean>>({});
  const [autoCloseEnabled, setAutoCloseEnabled] = useState(false);
  const [autoCloseDays, setAutoCloseDays] = useState("7");
  const [autoReplyEnabled, setAutoReplyEnabled] = useState(true);
  const [autoReplyTemplate, setAutoReplyTemplate] = useState("");

  useEffect(() => {
    if (mailboxes.length > 0 && !selectedId) {
      selectMailbox(mailboxes[0]);
    }
  }, [mailboxes]);

  function selectMailbox(m: Mailbox) {
    setSelectedId(m.id);
    setNotificationEvents(m.notification_events || {});
    setAutoCloseEnabled(m.auto_close_days !== null);
    setAutoCloseDays(String(m.auto_close_days || 7));
    setAutoReplyEnabled(m.auto_reply_enabled);
    setAutoReplyTemplate(m.auto_reply_template || "");
  }

  async function handleSave() {
    if (!selectedId) return;
    setSaving(true);
    try {
      await updateMailbox(selectedId, {
        notification_events: notificationEvents,
        auto_close_days: autoCloseEnabled ? parseInt(autoCloseDays, 10) : null,
        auto_reply_enabled: autoReplyEnabled,
        auto_reply_template: autoReplyTemplate || null,
      });
      toast.success("Settings saved");
    } catch {
      toast.error("Failed to save settings");
    } finally {
      setSaving(false);
    }
  }

  if (loading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="h-6 w-6 animate-spin text-muted-foreground" />
      </div>
    );
  }

  if (mailboxes.length === 0) {
    return (
      <Card>
        <CardContent className="py-12 text-center">
          <p className="text-muted-foreground">
            Add a mailbox first to configure help desk settings.
          </p>
        </CardContent>
      </Card>
    );
  }

  const eventLabels = HELPDESK_EVENT_LABELS;

  return (
    <div className="space-y-6">
      {/* Mailbox selector */}
      {mailboxes.length > 1 && (
        <div>
          <Label>Configure settings for</Label>
          <SearchableSelect
            className="w-64"
            value={String(selectedId)}
            onValueChange={(v) => {
              const m = mailboxes.find((mb) => mb.id === Number(v));
              if (m) selectMailbox(m);
            }}
            options={mailboxes.map((m) => ({
              value: String(m.id),
              label: `${m.name} (${m.email_address})`,
            }))}
            placeholder="Select mailbox…"
            searchPlaceholder="Search mailboxes…"
            emptyText="No mailboxes found"
          />
        </div>
      )}

      {/* Notification Events */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Email Notifications</CardTitle>
        </CardHeader>
        <CardContent className="space-y-3">
          <p className="text-sm text-muted-foreground mb-4">
            Choose which events send email notifications to ticket participants (requester + CC).
          </p>
          {Object.entries(eventLabels).map(([key, label]) => (
            <div key={key} className="flex items-center justify-between py-1">
              <Label className="font-normal">{label}</Label>
              <Switch
                checked={notificationEvents[key] ?? false}
                onCheckedChange={(c) =>
                  setNotificationEvents({ ...notificationEvents, [key]: c })
                }
              />
            </div>
          ))}
        </CardContent>
      </Card>

      {/* Auto-Reply */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Auto-Reply</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center gap-2">
            <Switch checked={autoReplyEnabled} onCheckedChange={setAutoReplyEnabled} />
            <Label>Send acknowledgement email when a new ticket is created</Label>
          </div>
          {autoReplyEnabled && (
            <div>
              <Label>Template (Liquid)</Label>
              <Textarea
                value={autoReplyTemplate}
                onChange={(e) => setAutoReplyTemplate(e.target.value)}
                rows={5}
                placeholder="Leave empty for default message. Available variables: {{ ticket_number }}, {{ subject }}, {{ sender_name }}"
              />
              <p className="text-xs text-muted-foreground mt-1">
                Uses Liquid template syntax. Leave empty for the default acknowledgement message.
              </p>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Auto-Close */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Auto-Close Inactive Tickets</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="flex items-center gap-2">
            <Switch checked={autoCloseEnabled} onCheckedChange={setAutoCloseEnabled} />
            <Label>Automatically close tickets after inactivity</Label>
          </div>
          {autoCloseEnabled && (
            <div className="flex items-center gap-2">
              <Label>Close after</Label>
              <Input
                type="number"
                className="w-20"
                value={autoCloseDays}
                onChange={(e) => setAutoCloseDays(e.target.value)}
                min="1"
              />
              <span className="text-sm text-muted-foreground">days of no activity</span>
            </div>
          )}
        </CardContent>
      </Card>

      <Button onClick={handleSave} disabled={saving}>
        {saving ? <Loader2 className="h-4 w-4 animate-spin mr-1" /> : <Save className="h-4 w-4 mr-1" />}
        Save Settings
      </Button>
    </div>
  );
}

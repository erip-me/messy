import { useState, useEffect, useCallback } from "react";
import { Plug, Copy, Check, RefreshCw, Users2, ScrollText } from "lucide-react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Switch } from "@/components/ui/switch";
import {
  Table,
  TableHeader,
  TableBody,
  TableHead,
  TableRow,
  TableCell,
} from "@/components/ui/table";
import { PageSkeleton } from "@/components/ui/table-skeleton";
import { useConfirm } from "@/components/ui/confirm-dialog";
import { usePageParam } from "@/hooks/usePageParam";
import { formatDate, timeAgo } from "@/utils/format-date";
import toast from "react-hot-toast";
import {
  getMcpSettings,
  updateMcpSettings,
  getMcpConnections,
  revokeMcpConnection,
  setMcpUserEnabled,
  getMcpLogs,
  McpConnection,
  McpUser,
  McpLog,
  McpLogStatus,
} from "@/api/mcp";

const LOG_STATUS_VARIANT: Record<McpLogStatus, "success" | "destructive" | "warning"> = {
  ok: "success",
  error: "destructive",
  rejected: "warning",
};

export function McpIndexPage() {
  const { confirm, ConfirmDialog } = useConfirm();

  const [loading, setLoading] = useState(true);
  const [enabled, setEnabled] = useState(false);
  const [serverUrl, setServerUrl] = useState("");
  const [savingMaster, setSavingMaster] = useState(false);
  const [copied, setCopied] = useState(false);

  const [connections, setConnections] = useState<McpConnection[]>([]);
  const [users, setUsers] = useState<McpUser[]>([]);

  const [logs, setLogs] = useState<McpLog[]>([]);
  const [logsLoading, setLogsLoading] = useState(false);
  const [page, setPage] = usePageParam();
  const [totalPages, setTotalPages] = useState(1);

  const loadSettings = useCallback(async () => {
    const [settings, conns] = await Promise.all([getMcpSettings(), getMcpConnections()]);
    setEnabled(settings.enabled);
    setServerUrl(settings.server_url);
    setConnections(conns.connections);
    setUsers(conns.users);
  }, []);

  const loadLogs = useCallback(async (p: number) => {
    setLogsLoading(true);
    try {
      const res = await getMcpLogs(p);
      setLogs(res.logs);
      setTotalPages(res.meta.total_pages || 1);
    } catch {
      toast.error("Failed to load usage logs");
    } finally {
      setLogsLoading(false);
    }
  }, []);

  useEffect(() => {
    (async () => {
      try {
        await loadSettings();
      } catch {
        toast.error("Failed to load MCP settings");
      } finally {
        setLoading(false);
      }
    })();
  }, [loadSettings]);

  useEffect(() => {
    loadLogs(page);
  }, [page, loadLogs]);

  const handleToggleMaster = async (value: boolean) => {
    setSavingMaster(true);
    try {
      const res = await updateMcpSettings(value);
      setEnabled(res.enabled);
      toast.success(value ? "MCP server enabled" : "MCP server disabled");
    } catch {
      toast.error("Failed to update MCP server");
    } finally {
      setSavingMaster(false);
    }
  };

  const handleCopy = () => {
    navigator.clipboard.writeText(serverUrl);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  const handleToggleUser = async (user: McpUser, value: boolean) => {
    setUsers((prev) => prev.map((u) => (u.id === user.id ? { ...u, mcp_enabled: value } : u)));
    try {
      await setMcpUserEnabled(user.id, value);
      // A user's gate affects all their connections' effective state.
      setConnections((prev) =>
        prev.map((c) => (c.user?.id === user.id ? { ...c, enabled: value && !c.revoked && enabled } : c))
      );
    } catch {
      setUsers((prev) => prev.map((u) => (u.id === user.id ? { ...u, mcp_enabled: !value } : u)));
      toast.error("Failed to update user access");
    }
  };

  const handleRevoke = async (conn: McpConnection) => {
    const ok = await confirm({
      title: "Revoke connection?",
      description: `This immediately disconnects ${conn.client_name || "this agent"} for ${
        conn.user?.name || "the user"
      }. The agent must reconnect to regain access.`,
      confirmLabel: "Revoke",
      variant: "destructive",
    });
    if (!ok) return;
    try {
      await revokeMcpConnection(conn.id);
      setConnections((prev) =>
        prev.map((c) => (c.id === conn.id ? { ...c, revoked: true, enabled: false } : c))
      );
      toast.success("Connection revoked");
    } catch {
      toast.error("Failed to revoke connection");
    }
  };

  if (loading) return <PageSkeleton variant="table" rows={8} />;

  return (
    <div className="p-6 max-w-5xl">
      <div className="flex items-center gap-2 mb-6">
        <Plug className="h-5 w-5 text-muted-foreground" />
        <h1 className="text-2xl font-bold">MCP Server</h1>
      </div>

      {/* Master switch + connection details */}
      <Card>
        <CardHeader>
          <div className="flex items-start justify-between gap-4">
            <div>
              <CardTitle className="text-base">Model Context Protocol</CardTitle>
              <CardDescription>
                Let AI agents (Claude, OpenAI, and any MCP client) act on this account through a
                secure OAuth connection. Turn this off to instantly block every agent.
              </CardDescription>
            </div>
            <Switch checked={enabled} disabled={savingMaster} onCheckedChange={handleToggleMaster} />
          </div>
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            <p className="text-sm font-medium">Connection URL</p>
            <div className="flex items-center gap-2">
              <code className="text-xs bg-muted px-3 py-2 rounded flex-1 break-all">{serverUrl}</code>
              <Button variant="outline" size="sm" onClick={handleCopy}>
                {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
              </Button>
            </div>
            <p className="text-xs text-muted-foreground">
              Add this as a custom connector in Claude, or as a remote MCP server in OpenAI. The
              agent walks through an OAuth sign-in and you approve which environment it can access.
            </p>
          </div>
        </CardContent>
      </Card>

      {/* Per-user access */}
      <Card className="mt-6">
        <CardHeader>
          <div className="flex items-center gap-2">
            <Users2 className="h-4 w-4 text-muted-foreground" />
            <CardTitle className="text-base">User access</CardTitle>
          </div>
          <CardDescription>
            Control which team members may connect agents. Disabling a user blocks all of their
            connections at once.
          </CardDescription>
        </CardHeader>
        <CardContent>
          {users.length === 0 ? (
            <p className="text-sm text-muted-foreground">No users found.</p>
          ) : (
            <div className="divide-y">
              {users.map((u) => (
                <div key={u.id} className="flex items-center justify-between py-3">
                  <div>
                    <p className="text-sm font-medium">{u.name}</p>
                    <p className="text-xs text-muted-foreground">{u.email}</p>
                  </div>
                  <Switch
                    checked={u.mcp_enabled}
                    onCheckedChange={(v) => handleToggleUser(u, v)}
                  />
                </div>
              ))}
            </div>
          )}
        </CardContent>
      </Card>

      {/* Connections */}
      <Card className="mt-6">
        <CardHeader>
          <CardTitle className="text-base">Connections</CardTitle>
          <CardDescription>Agents that have connected to this account.</CardDescription>
        </CardHeader>
        <CardContent>
          {connections.length === 0 ? (
            <p className="text-sm text-muted-foreground">No agents have connected yet.</p>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Agent</TableHead>
                    <TableHead>User</TableHead>
                    <TableHead>Environment</TableHead>
                    <TableHead>Scopes</TableHead>
                    <TableHead>Last used</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead className="text-right">Actions</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {connections.map((c) => (
                    <TableRow key={c.id}>
                      <TableCell className="font-medium">{c.client_name || "Unknown"}</TableCell>
                      <TableCell>
                        <div className="text-sm">{c.user?.name}</div>
                        <div className="text-xs text-muted-foreground">{c.user?.email}</div>
                      </TableCell>
                      <TableCell className="text-sm">{c.environment?.name || "—"}</TableCell>
                      <TableCell>
                        <div className="flex flex-wrap gap-1 max-w-xs">
                          {c.scopes.map((s) => (
                            <Badge key={s} variant="secondary" className="text-[10px]">
                              {s}
                            </Badge>
                          ))}
                        </div>
                      </TableCell>
                      <TableCell className="text-xs text-muted-foreground">
                        {c.last_used_at ? timeAgo(c.last_used_at) : "never"}
                      </TableCell>
                      <TableCell>
                        {c.revoked ? (
                          <Badge variant="outline">Revoked</Badge>
                        ) : c.enabled ? (
                          <Badge variant="success">Active</Badge>
                        ) : (
                          <Badge variant="warning">Disabled</Badge>
                        )}
                      </TableCell>
                      <TableCell className="text-right">
                        {!c.revoked && (
                          <Button variant="ghost" size="sm" onClick={() => handleRevoke(c)}>
                            Revoke
                          </Button>
                        )}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}
        </CardContent>
      </Card>

      {/* Usage logs */}
      <Card className="mt-6">
        <CardHeader>
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <ScrollText className="h-4 w-4 text-muted-foreground" />
              <CardTitle className="text-base">Usage logs</CardTitle>
            </div>
            <Button variant="outline" size="sm" onClick={() => loadLogs(page)} disabled={logsLoading}>
              <RefreshCw className={`h-4 w-4 mr-2 ${logsLoading ? "animate-spin" : ""}`} />
              Refresh
            </Button>
          </div>
          <CardDescription>Every tool call made by a connected agent.</CardDescription>
        </CardHeader>
        <CardContent>
          {logs.length === 0 ? (
            <p className="text-sm text-muted-foreground">No tool calls yet.</p>
          ) : (
            <div className="overflow-x-auto">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead>Time</TableHead>
                    <TableHead>User</TableHead>
                    <TableHead>Tool</TableHead>
                    <TableHead>Status</TableHead>
                    <TableHead>Duration</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {logs.map((l) => (
                    <TableRow key={l.id}>
                      <TableCell className="text-xs text-muted-foreground whitespace-nowrap">
                        {formatDate(l.created_at)}
                      </TableCell>
                      <TableCell className="text-sm">{l.user?.name || "—"}</TableCell>
                      <TableCell className="font-mono text-xs">{l.tool_name}</TableCell>
                      <TableCell>
                        <Badge variant={LOG_STATUS_VARIANT[l.status]}>{l.status}</Badge>
                        {l.error_message && (
                          <span className="ml-2 text-xs text-muted-foreground">{l.error_message}</span>
                        )}
                      </TableCell>
                      <TableCell className="text-xs text-muted-foreground">
                        {l.duration_ms != null ? `${l.duration_ms} ms` : "—"}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          )}

          {totalPages > 1 && (
            <div className="flex items-center justify-center gap-3 mt-6">
              <Button variant="outline" size="sm" disabled={page === 1} onClick={() => setPage(page - 1)}>
                Previous
              </Button>
              <span className="text-sm text-muted-foreground">
                Page {page} of {totalPages}
              </span>
              <Button
                variant="outline"
                size="sm"
                disabled={page === totalPages}
                onClick={() => setPage(page + 1)}
              >
                Next
              </Button>
            </div>
          )}
        </CardContent>
      </Card>

      {ConfirmDialog}
    </div>
  );
}

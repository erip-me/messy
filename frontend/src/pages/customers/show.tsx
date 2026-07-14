import { useState, useEffect, useMemo } from "react";
import { useNavigate, useParams } from "react-router-dom";
import {
  ArrowLeft,
  Mail,
  Tag,
  Copy,
  Check,
  Trash2,
  Clock,
  Globe,
  Monitor,
  BellOff,
} from "lucide-react";
import { format } from "date-fns";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Separator } from "@/components/ui/separator";
import { Skeleton } from "@/components/ui/skeleton";
import { Switch } from "@/components/ui/switch";
import toast from "react-hot-toast";
import { useConfirm } from "@/components/ui/confirm-dialog";
import { HelpHint } from "@/components/ui/help-hint";
import { Customer, CustomerActivity, CustomerMessage, getCustomer, deleteCustomer, toggleUnsubscribe, unsubscribeAll, toggleCategoryUnsubscribe } from "@/api/customers";
import { ChannelTypeIcon } from "@/components/channel-icons";


import { statusClass } from "@/lib/status-colors";
import { UNSUB_REASON_LABELS } from "@/lib/labels";
import { activityConfig, dedupeLatest } from "@/lib/activity-config";
import { copyToClipboard } from "@/utils/clipboard";
import { getInitials } from "@/utils/initials";

interface PageVisitItem {
  id: number;
  url: string;
  title: string | null;
  visited_at: string;
}

type TimelineItem =
  | { kind: "activity"; data: CustomerActivity; time: number }
  | { kind: "message"; data: CustomerMessage; time: number }
  | { kind: "page_visit"; data: PageVisitItem; time: number };

// Render a custom-attribute value as readable text. Booleans are the important
// case: a bare `true` renders as nothing in JSX, so booleans looked blank —
// make true/false explicit. Empty/missing values fall back to an em dash.
const formatAttrValue = (value: unknown): string => {
  if (value === null || value === undefined || value === "") return "—";
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "object") return JSON.stringify(value);
  return String(value);
};

export function CustomerShowPage() {
  const { id } = useParams();
  const navigate = useNavigate();

  const [customer, setCustomer] = useState<Customer | null>(null);
  const [loading, setLoading] = useState(true);
  const [copied, setCopied] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const { confirm, ConfirmDialog } = useConfirm();

  useEffect(() => {
    if (id) loadCustomer();
  }, [id]);

  const loadCustomer = async () => {
    try {
      setLoading(true);
      const data = await getCustomer(parseInt(id!));
      setCustomer(data);
    } catch {
      toast.error("Failed to load customer");
    } finally {
      setLoading(false);
    }
  };

  const copyEmail = () => {
    if (!customer) return;
    copyToClipboard(customer.email);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  const handleDelete = async () => {
    if (!customer) return;
    const confirmed = await confirm({ title: "Delete Contact", description: "Delete this contact?", confirmLabel: "Delete", variant: "destructive" });
    if (!confirmed) return;
    try {
      setDeleting(true);
      await deleteCustomer(customer.id);
      toast.success("Customer deleted");
      navigate("/customers");
    } catch {
      toast.error("Failed to delete customer");
    } finally {
      setDeleting(false);
    }
  };

  const fullName = [customer?.first_name, customer?.last_name].filter(Boolean).join(" ");
  const initials = getInitials(customer?.first_name, customer?.last_name, customer?.email);
  const customAttrs = Object.entries(customer?.custom_attributes || {});

  const timelineItems = useMemo((): TimelineItem[] => {
    if (!customer) return [];
    // Keep only the most recent occurrence of each activity type per campaign so
    // repeated opens/logins collapse into a single row.
    const activitiesNewestFirst = [...(customer.activities || [])].sort(
      (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
    );
    const dedupedActivities = dedupeLatest(
      activitiesNewestFirst,
      (a) => `${a.activity_type}|${String(a.properties?.campaign_id ?? "")}|${String(a.properties?.segment_id ?? "")}`
    );
    return [
      ...dedupedActivities.map((a) => ({
        kind: "activity" as const, data: a, time: new Date(a.created_at).getTime(),
      })),
      ...(customer.messages || []).map((m) => ({
        kind: "message" as const, data: m, time: new Date(m.created_at).getTime(),
      })),
      ...((customer as any).page_visits || []).map((v: PageVisitItem) => ({
        kind: "page_visit" as const, data: v, time: new Date(v.visited_at).getTime(),
      })),
    ].sort((a, b) => b.time - a.time);
  }, [customer]);

  if (loading) {
    return (
      <div className="p-6">
        <div className="flex items-center gap-4 mb-6">
          <Skeleton className="h-10 w-10" />
          <div>
            <Skeleton className="h-8 w-64" />
            <Skeleton className="h-4 w-32 mt-2" />
          </div>
        </div>
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2">
            <Skeleton className="h-96" />
          </div>
          <div className="space-y-6">
            <Skeleton className="h-64" />
          </div>
        </div>
      </div>
    );
  }

  if (!customer) {
    return (
      <div className="p-6">
        <div className="text-center py-12">
          <Mail className="h-12 w-12 text-muted-foreground mx-auto mb-4" />
          <h3 className="text-lg font-medium mb-2">Contact not found</h3>
          <Button onClick={() => navigate("/customers")}>Back to Contacts</Button>
        </div>
      </div>
    );
  }

  return (
    <div className="p-6">
      {/* Header */}
      <div className="flex flex-col gap-4 sm:flex-row sm:justify-between sm:items-center mb-6">
        <div className="flex items-center gap-4">
          <Button variant="ghost" size="sm" onClick={() => navigate(-1)}>
            <ArrowLeft className="h-4 w-4" />
          </Button>
          <div className="flex min-w-0 items-center gap-4">
            <div className="w-12 h-12 shrink-0 rounded-full bg-primary/10 flex items-center justify-center">
              <span className="text-lg font-bold text-primary">{initials}</span>
            </div>
            <div className="min-w-0">
              <h1 className="page-heading break-words">{fullName || customer.email}</h1>
              <p className="page-subtitle">Contact #{customer.id}</p>
            </div>
          </div>
        </div>

        <div className="flex items-center gap-2 flex-wrap">
          {(["email", "sms", "whatsapp", "push"] as const)
            .filter((ch) => customer.unsubscribed_channels?.[ch])
            .map((ch) => (
              <Badge key={ch} className="bg-orange-100 text-orange-700 hover:bg-orange-100 text-xs gap-1">
                <BellOff className="h-3 w-3" />
                Unsub {ch}
              </Badge>
            ))}
          <Button
            variant="ghost"
            size="sm"
            className="text-destructive hover:text-destructive hover:bg-destructive/10"
            onClick={handleDelete}
            disabled={deleting}
          >
            <Trash2 className="h-4 w-4 mr-2" />
            Delete
          </Button>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Main Content — Combined Timeline */}
        <div className="lg:col-span-2">
          <Card className="card-shadow bg-card">
            <CardHeader>
              <CardTitle className="text-foreground flex items-center gap-2">
                <Clock className="h-5 w-5" />
                Activity
              </CardTitle>
            </CardHeader>
            <CardContent>
              {timelineItems.length === 0 ? (
                <div className="text-center py-12 text-muted-foreground">
                  <Clock className="h-10 w-10 mx-auto mb-3 opacity-40" />
                  <p>No activity recorded yet</p>
                </div>
              ) : (
                <div className="space-y-3">
                  {timelineItems.map((item) => {
                      if (item.kind === "activity") {
                        const activity = item.data;
                        const config = activityConfig(activity.activity_type);
                        const ActivityIcon = config.Icon;
                        return (
                          <div
                            key={`a-${activity.id}`}
                            className={`flex items-start gap-4 p-4 rounded-lg border ${config.bg}`}
                          >
                            <div className={`w-8 h-8 rounded-full bg-muted flex items-center justify-center shrink-0 mt-0.5`}>
                              <ActivityIcon className={`h-4 w-4 ${config.iconColor}`} />
                            </div>
                            <div className="flex-1 min-w-0">
                              <div className="flex items-center gap-2 mb-1">
                                <span className="text-sm font-medium">{config.label}</span>
                                {activity.properties?.campaign_name && (
                                  <span className="text-xs text-muted-foreground">
                                    ({String(activity.properties.campaign_name)})
                                  </span>
                                )}
                                {activity.properties?.segment_name && (
                                  <span className="text-xs text-muted-foreground">
                                    ({String(activity.properties.segment_name)})
                                  </span>
                                )}
                                {activity.environment && (
                                  <Badge variant="outline" className="text-xs">
                                    {activity.environment}
                                  </Badge>
                                )}
                              </div>
                              <p className="text-xs text-muted-foreground">
                                {format(new Date(activity.created_at), "MMM d, yyyy · h:mm:ss a")}
                              </p>
                              {activity.properties && Object.keys(activity.properties).length > 0 && (
                                <div className="mt-2 flex gap-4 text-xs text-muted-foreground">
                                  {activity.properties.url && (
                                    <span className="flex items-center gap-1 truncate max-w-xs">
                                      <Globe className="h-3 w-3 shrink-0" />
                                      {String(activity.properties.url)}
                                    </span>
                                  )}
                                  {activity.properties.ip_address && (
                                    <span className="flex items-center gap-1">
                                      <Globe className="h-3 w-3" />
                                      {String(activity.properties.ip_address)}
                                    </span>
                                  )}
                                  {activity.properties.user_agent && (
                                    <span className="flex items-center gap-1 truncate max-w-xs">
                                      <Monitor className="h-3 w-3 shrink-0" />
                                      {String(activity.properties.user_agent)}
                                    </span>
                                  )}
                                </div>
                              )}
                            </div>
                          </div>
                        );
                      }

                      if (item.kind === "page_visit") {
                        const visit = item.data;
                        let pathname = "/";
                        try { pathname = new URL(visit.url).pathname; } catch { /* ignore */ }
                        return (
                          <div
                            key={`pv-${visit.id}`}
                            className="flex items-start gap-4 p-4 rounded-lg border bg-muted/50"
                          >
                            <div className="w-8 h-8 rounded-full bg-muted flex items-center justify-center shrink-0 mt-0.5">
                              <Globe className="h-4 w-4 text-muted-foreground" />
                            </div>
                            <div className="flex-1 min-w-0">
                              <div className="flex items-center gap-2 mb-1">
                                <span className="text-sm font-medium">Visited page</span>
                              </div>
                              <a
                                href={visit.url}
                                target="_blank"
                                rel="noopener"
                                className="text-xs text-primary hover:underline break-all"
                              >
                                {visit.title || pathname}
                              </a>
                              <p className="text-[10px] text-muted-foreground mt-0.5">{pathname}</p>
                              <p className="text-xs text-muted-foreground mt-1">
                                {format(new Date(visit.visited_at), "MMM d, yyyy · h:mm:ss a")}
                              </p>
                            </div>
                          </div>
                        );
                      }

                      const msg = item.data as CustomerMessage;
                      return (
                        <div
                          key={`m-${msg.id}`}
                          className="flex items-start gap-4 p-4 rounded-lg border cursor-pointer hover:bg-muted/30 transition-colors"
                          onClick={() => navigate(`/messages/${msg.id}`)}
                        >
                          <div className="w-8 h-8 rounded-full bg-muted flex items-center justify-center shrink-0 mt-0.5">
                            <ChannelTypeIcon type={msg.channel} size={16} />
                          </div>
                          <div className="flex-1 min-w-0">
                            <div className="flex items-center gap-2 mb-1">
                              <span className="text-sm font-medium truncate">
                                {msg.subject || `${msg.channel.toUpperCase()} message`}
                              </span>
                              <span className={`${statusClass(msg.status)} text-xs shrink-0 ml-auto`}>
                                {msg.status}
                              </span>
                            </div>
                            <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
                              <Badge variant="outline" className="text-xs shrink-0">
                                {msg.channel.toUpperCase()}
                              </Badge>
                              {msg.environment && (
                                <Badge variant="outline" className="text-xs shrink-0">
                                  {msg.environment}
                                </Badge>
                              )}
                              <span className="text-xs text-muted-foreground font-mono">
                                {format(new Date(msg.created_at), "MMM d, yyyy · h:mm:ss a")}
                              </span>
                            </div>
                          </div>
                        </div>
                      );
                  })}
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Sidebar */}
        <div className="space-y-6">
          {/* Details Card */}
          <Card className="card-shadow bg-card">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-medium text-muted-foreground flex items-center gap-2">
                <Mail className="h-4 w-4" />
                Details
              </CardTitle>
            </CardHeader>
            <CardContent>
              <div className="space-y-3 text-sm">
                <div>
                  <span className="text-muted-foreground text-xs block mb-1">Email</span>
                  <div className="flex items-center gap-2">
                    <span className="font-mono text-xs">{customer.email}</span>
                    <button
                      onClick={copyEmail}
                      className="text-muted-foreground hover:text-foreground transition-colors"
                    >
                      {copied ? (
                        <Check className="h-3.5 w-3.5 text-green-500" />
                      ) : (
                        <Copy className="h-3.5 w-3.5" />
                      )}
                    </button>
                  </div>
                </div>

                {customer.email_score !== null && customer.email_score !== undefined && (
                  <div>
                    <span className="text-muted-foreground text-xs block mb-1">Email Score</span>
                    <div className="flex items-center gap-2">
                      <Badge
                        variant={
                          customer.email_score >= 70
                            ? "success"
                            : customer.email_score >= 40
                              ? "warning"
                              : "destructive"
                        }
                      >
                        {customer.email_score}
                      </Badge>
                      {customer.email_score_checked_at && (
                        <span className="text-xs text-muted-foreground">
                          checked {format(new Date(customer.email_score_checked_at), "MMM d, yyyy")}
                        </span>
                      )}
                    </div>
                  </div>
                )}

                {customer.first_name && (
                  <div>
                    <span className="text-muted-foreground text-xs block mb-1">First Name</span>
                    <span>{customer.first_name}</span>
                  </div>
                )}

                {customer.last_name && (
                  <div>
                    <span className="text-muted-foreground text-xs block mb-1">Last Name</span>
                    <span>{customer.last_name}</span>
                  </div>
                )}

                <Separator />

                <div className="flex justify-between items-center">
                  <span className="text-muted-foreground">Created</span>
                  <span className="font-mono text-xs">
                    {format(new Date(customer.created_at), "MMM d, yyyy")}
                  </span>
                </div>

                {customer.last_seen_at && (
                  <div className="flex justify-between items-center">
                    <span className="text-muted-foreground">Last Seen</span>
                    <span className="font-mono text-xs">
                      {format(new Date(customer.last_seen_at), "MMM d, yyyy · h:mm a")}
                    </span>
                  </div>
                )}
              </div>
            </CardContent>
          </Card>

          {/* Subscription Status Card */}
          <Card className="card-shadow bg-card">
            <CardHeader className="pb-3">
              <div className="flex items-center justify-between">
                <CardTitle className="text-sm font-medium text-muted-foreground flex items-center gap-2">
                  <BellOff className="h-4 w-4" />
                  Subscriptions
                  <HelpHint label="How subscriptions work">
                    A channel switch is a hard block. Turning off Email suppresses{' '}
                    <strong className="text-foreground">every</strong> email to this contact,
                    transactional ones included. Those messages are recorded with the status{' '}
                    <code className="font-mono">suppressed</code> rather than sent.
                  </HelpHint>
                </CardTitle>
                <Button
                  variant="ghost"
                  size="sm"
                  className="text-xs text-muted-foreground h-auto py-1 px-2"
                  onClick={async () => {
                    try {
                      const result = await unsubscribeAll(customer.id);
                      setCustomer((prev) =>
                        prev
                          ? { ...prev, unsubscribed_channels: result.unsubscribed_channels }
                          : prev
                      );
                      toast.success(result.message);
                    } catch {
                      toast.error("Failed to update subscriptions");
                    }
                  }}
                >
                  {(["email", "sms", "whatsapp", "push"] as const).every(
                    (ch) => customer.unsubscribed_channels?.[ch]
                  )
                    ? "Resubscribe all"
                    : "Unsubscribe all"}
                </Button>
              </div>
            </CardHeader>
            <CardContent>
              <div className="space-y-3">
                {(["email", "sms", "whatsapp", "push"] as const).map((channel) => {
                  const unsubValue = customer.unsubscribed_channels?.[channel];
                  const isSubscribed = !unsubValue;
                  const reason = unsubValue && typeof unsubValue === 'object' && 'reason' in unsubValue
                    ? (unsubValue as { reason: string }).reason
                    : null;
                  return (
                    <div key={channel}>
                      <div className="flex items-center justify-between">
                        <div className="flex items-center gap-2">
                          <span className="text-sm capitalize">{channel}</span>
                          {!isSubscribed && reason && (
                            <Badge variant="destructive" className="text-[10px] py-0 px-1.5">
                              {UNSUB_REASON_LABELS[reason] || reason}
                            </Badge>
                          )}
                        </div>
                        <Switch
                          checked={isSubscribed}
                          onCheckedChange={async () => {
                            try {
                              const result = await toggleUnsubscribe(customer.id, channel);
                              setCustomer(prev => prev ? {
                                ...prev,
                                unsubscribed_channels: result.unsubscribed_channels
                              } : prev);
                              toast.success(result.message);
                            } catch {
                              toast.error("Failed to update subscription");
                            }
                          }}
                        />
                      </div>
                    </div>
                  );
                })}

                {/* Marketing category — drips & campaigns; never affects system emails */}
                <div className="pt-3 mt-1 border-t">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <span className="text-sm">Marketing</span>
                      <HelpHint label="What the marketing opt-out covers">
                        Only drips and campaigns check this. Transactional messages (OTPs, receipts,
                        password resets) are never blocked by a marketing opt-out. To stop those too,
                        turn off the channel above.
                      </HelpHint>
                      {customer.unsubscribed_categories?.marketing && (
                        <Badge variant="destructive" className="text-[10px] py-0 px-1.5">Opted out</Badge>
                      )}
                    </div>
                    <Switch
                      checked={!customer.unsubscribed_categories?.marketing}
                      onCheckedChange={async () => {
                        try {
                          const result = await toggleCategoryUnsubscribe(customer.id, "marketing");
                          setCustomer(prev => prev ? { ...prev, unsubscribed_categories: result.unsubscribed_categories } : prev);
                          toast.success(result.message);
                        } catch {
                          toast.error("Failed to update subscription");
                        }
                      }}
                    />
                  </div>
                  <p className="text-xs text-muted-foreground mt-0.5">Drips &amp; campaigns. System emails are never affected.</p>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Custom Attributes Card */}
          <Card className="card-shadow bg-card">
            <CardHeader className="pb-3">
              <CardTitle className="text-sm font-medium text-muted-foreground flex items-center gap-2">
                <Tag className="h-4 w-4" />
                Custom Attributes
                <Badge variant="secondary" className="text-xs">
                  {customAttrs.length}
                </Badge>
              </CardTitle>
            </CardHeader>
            <CardContent>
              {customAttrs.length > 0 ? (
                <div className="space-y-1.5">
                  {customAttrs.map(([key, value]) => (
                    <div
                      key={key}
                      className="flex items-center justify-between gap-4 rounded-lg border bg-muted/30 px-3 py-2"
                    >
                      <span className="text-xs font-semibold text-muted-foreground uppercase tracking-wide shrink-0">
                        {key}
                      </span>
                      <span className="text-sm font-mono text-right break-all">{formatAttrValue(value)}</span>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-muted-foreground italic">No custom attributes</p>
              )}
            </CardContent>
          </Card>
        </div>
      </div>

      {ConfirmDialog}
    </div>
  );
}

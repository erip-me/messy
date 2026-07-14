import { useState, useEffect, useRef, useCallback } from "react";
import { useParams, useNavigate, useSearchParams } from "react-router-dom";
import { useSelector } from "react-redux";
import { createAuthenticatedConsumer } from "@/utils/cable";
import { RootState } from "../../store";
import { Badge } from "../../components/ui/badge";
import { Button } from "../../components/ui/button";
import { Input } from "../../components/ui/input";
import { Tabs, TabsList, TabsTrigger } from "../../components/ui/tabs";
import {
  getConversations,
  getConversation,
  sendConversationMessage,
  updateConversation,
  assignConversation,
  markConversationRead,
  markConversationUnread,
  getConversationStats,
  ConversationSummary,
  ConversationDetail,
  ChatMessage,
} from "../../api/conversations";
import { getCannedResponses, getChatSettings, CannedResponse, WidgetSettings } from "../../api/chat-settings";
import { MessageCircle, Send, Check, User, Search, Paperclip, Smile, X, Download, ChevronDown, Mail, Inbox, MoreHorizontal, CheckCircle2, EyeOff, RotateCcw, Archive } from "lucide-react";
import toast from "react-hot-toast";
import { tagStyle } from "../../utils/tag-colors";
import { timeAgo } from "../../utils/format-date";
import { useClickOutside } from "../../hooks/useClickOutside";
import { useDebouncedValue } from "../../hooks/useDebouncedValue";
import { ticketNum } from "../../utils/ticket";
import { getUsers, User as AccountUser } from "../../api/users";

interface CustomerDetail {
  id: number;
  email: string | null;
  first_name: string | null;
  last_name: string | null;
  online: boolean;
  country: string | null;
  city: string | null;
  browser: string | null;
  os: string | null;
  last_seen_at: string | null;
  recent_pages: { url: string; title: string | null; visited_at: string }[];
  custom_attributes: Record<string, unknown>;
}



export function InboxPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { user, account } = useSelector((state: RootState) => state.auth);

  const [conversations, setConversations] = useState<ConversationSummary[]>([]);
  const [activeConversation, setActiveConversation] = useState<ConversationDetail | null>(null);
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [customer, setCustomer] = useState<CustomerDetail | null>(null);
  const [messageText, setMessageText] = useState("");
  const [isPrivate, setIsPrivate] = useState(false);
  const [filter, setFilter] = useState<"mine" | "unassigned" | "all">(() => {
    const v = searchParams.get("assigned");
    return v === "unassigned" || v === "all" ? v : "mine";
  });
  const [sourceFilter, setSourceFilter] = useState<"" | "widget" | "email">(() => {
    const v = searchParams.get("source");
    return v === "widget" || v === "email" ? v : "";
  });
  const [showFilterMenu, setShowFilterMenu] = useState(false);
  const filterMenuRef = useRef<HTMLDivElement>(null);
  const [statusFilter, setStatusFilter] = useState(() => searchParams.get("status") || "");
  const [searchInput, setSearchInput] = useState(() => searchParams.get("q") || "");
  const search = useDebouncedValue(searchInput, 300);
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [attachments, setAttachments] = useState<{ file: File; preview: string | null }[]>([]);
  const [showEmoji, setShowEmoji] = useState(false);
  const [cannedResults, setCannedResults] = useState<CannedResponse[]>([]);
  const [cannedIndex, setCannedIndex] = useState(0);
  const [cannedQuery, setCannedQuery] = useState<string | null>(null);
  const [widgetColors, setWidgetColors] = useState<Pick<WidgetSettings, "primary_color" | "secondary_color" | "text_color"> | null>(null);
  const [operators, setOperators] = useState<AccountUser[]>([]);
  const currentOperator = operators.find((o) => o.id === user?.id);
  const [filterCounts, setFilterCounts] = useState<{ mine: number; unassigned: number; all: number }>({ mine: 0, unassigned: 0, all: 0 });
  const [showAssignMenu, setShowAssignMenu] = useState(false);
  const [showActionsMenu, setShowActionsMenu] = useState(false);
  const actionsMenuRef = useRef<HTMLDivElement>(null);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const replyInputRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const emojiRef = useRef<HTMLDivElement>(null);
  const cannedRef = useRef<HTMLDivElement>(null);
  const cableRef = useRef<any>(null);
  const activeConversationIdRef = useRef<number | null>(null);
  const assignMenuRef = useRef<HTMLDivElement>(null);

  const refreshFilterCounts = useCallback(() => {
    getConversationStats().then((res) => {
      setFilterCounts({
        mine: res.data.unread_mine,
        unassigned: res.data.unread_unassigned,
        all: res.data.unread,
      });
    }).catch(() => {});
  }, []);

  const loadConversations = useCallback(async () => {
    try {
      const params: Record<string, string> = {};
      if (statusFilter) params.status = statusFilter;
      if (filter === "mine") params.assigned_to = "me";
      if (filter === "unassigned") params.assigned_to = "unassigned";
      if (sourceFilter) params.source = sourceFilter;
      if (search) params.q = search;

      const res = await getConversations(params);
      setConversations(res.data.conversations);
      refreshFilterCounts();
    } catch {
      toast.error("Failed to load conversations");
    } finally {
      setLoading(false);
    }
  }, [filter, statusFilter, sourceFilter, search, refreshFilterCounts]);

  useEffect(() => {
    loadConversations();
  }, [loadConversations]);

  useEffect(() => {
    const handler = () => refreshFilterCounts();
    window.addEventListener("messy:inbox-read", handler);
    return () => window.removeEventListener("messy:inbox-read", handler);
  }, [refreshFilterCounts]);

  useEffect(() => {
    getChatSettings().then((res) => {
      const s = res.data.widget_settings;
      setWidgetColors({ primary_color: s.primary_color, secondary_color: s.secondary_color, text_color: s.text_color });
    }).catch(() => {});
    getUsers().then(setOperators).catch(() => {});
  }, []);

  useClickOutside(filterMenuRef, showFilterMenu, () => setShowFilterMenu(false));
  useClickOutside(assignMenuRef, showAssignMenu, () => setShowAssignMenu(false));
  useClickOutside(actionsMenuRef, showActionsMenu, () => setShowActionsMenu(false));

  useEffect(() => {
    if (id) loadConversation(Number(id));
  }, [id]);

  useEffect(() => {
    activeConversationIdRef.current = activeConversation?.id ?? null;
  }, [activeConversation?.id]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  // Canned responses: fetch when "/" query changes
  useEffect(() => {
    if (cannedQuery === null) { setCannedResults([]); return; }
    const t = setTimeout(() => {
      getCannedResponses(cannedQuery || undefined)
        .then((res) => { setCannedResults(res.data.canned_responses); setCannedIndex(0); })
        .catch(() => {});
    }, 100);
    return () => clearTimeout(t);
  }, [cannedQuery]);

  useClickOutside(cannedRef, cannedQuery !== null, () => setCannedQuery(null));
  useClickOutside(emojiRef, showEmoji, () => setShowEmoji(false));

  // WebSocket for inbox updates
  useEffect(() => {
    if (!account) return;
    const cable = createAuthenticatedConsumer();
    if (!cable) return;

    const subscription = cable.subscriptions.create(
      { channel: "OperatorInboxChannel" },
      {
        received(data: any) {
          if (data.type === "new_conversation" || data.type === "conversation_update") {
            loadConversations();
          }
          if (data.type === "visitor_online" || data.type === "visitor_offline") {
            loadConversations();
            if (activeConversationIdRef.current) {
              loadConversation(activeConversationIdRef.current);
            }
          }
          if (data.type === "new_message" && activeConversationIdRef.current === data.conversation_id) {
            setMessages((prev) => {
              if (prev.find((m) => m.id === data.message.id)) return prev;
              return [...prev, data.message];
            });
            markConversationRead(data.conversation_id).then(() => {
              window.dispatchEvent(new Event("messy:inbox-read"));
            }).catch(() => {});
          }
        },
      }
    );

    cableRef.current = cable;
    return () => {
      subscription.unsubscribe();
      cable.disconnect();
    };
  }, [account?.id]);

  async function loadConversation(convId: number) {
    try {
      const res = await getConversation(convId);
      setActiveConversation(res.data.conversation);
      setMessages(res.data.messages);
      setCustomer(res.data.customer);

      setTimeout(() => replyInputRef.current?.focus(), 0);

      if (res.data.messages.length > 0) {
        markConversationRead(convId).then(() => {
          setConversations((prev) =>
            prev.map((c) => (c.id === convId ? { ...c, unread_count: 0 } : c))
          );
          window.dispatchEvent(new Event("messy:inbox-read"));
        }).catch(() => {});
      }
    } catch {
      toast.error("Failed to load conversation");
    }
  }

  async function handleSend() {
    if ((!messageText.trim() && attachments.length === 0) || !activeConversation) return;
    setSending(true);
    try {
      const res = await sendConversationMessage(activeConversation.id, {
        content: messageText.trim(),
        private: isPrivate,
        attachments: attachments.length > 0 ? attachments.map((a) => a.file) : undefined,
      });
      setMessages((prev) => {
        if (prev.find((m) => m.id === res.data.message.id)) return prev;
        return [...prev, res.data.message];
      });
      setMessageText("");
      setAttachments((prev) => { prev.forEach((a) => a.preview && URL.revokeObjectURL(a.preview)); return []; });
    } catch {
      toast.error("Failed to send message");
    } finally {
      setSending(false);
    }
  }

  function selectCannedResponse(response: CannedResponse) {
    // Replace the "/query" text with the canned response content
    const ta = replyInputRef.current;
    if (ta) {
      const cursor = ta.selectionStart;
      const text = messageText;
      // Find the "/" that started this query
      let slashPos = cursor - 1;
      while (slashPos >= 0 && text[slashPos] !== "/") slashPos--;
      if (slashPos >= 0) {
        const before = text.slice(0, slashPos);
        const after = text.slice(cursor);
        setMessageText(before + response.content + after);
        requestAnimationFrame(() => {
          ta.selectionStart = ta.selectionEnd = slashPos + response.content.length;
          ta.focus();
        });
      }
    }
    setCannedQuery(null);
  }

  async function handleAssign(userId: number) {
    if (!activeConversation) return;
    try {
      const res = await assignConversation(activeConversation.id, userId);
      setActiveConversation(res.data.conversation);
      loadConversations();
      setShowAssignMenu(false);
      const assignee = operators.find((o) => o.id === userId);
      toast.success(`Assigned to ${assignee?.name || "operator"}`);
    } catch {
      toast.error("Failed to assign conversation");
    }
  }

  async function handleStatusChange(status: string, label: string) {
    if (!activeConversation) return;
    try {
      await updateConversation(activeConversation.id, { status });
      toast.success(label);
      loadConversations();
      setActiveConversation(null);
      navigate("/inbox");
    } catch {
      toast.error(`Failed to update status`);
    }
  }

  async function handleMarkUnread() {
    if (!activeConversation) return;
    try {
      await markConversationUnread(activeConversation.id);
      setConversations((prev) =>
        prev.map((c) => (c.id === activeConversation.id ? { ...c, unread_count: Math.max(c.unread_count, 1) } : c))
      );
      setActiveConversation(null);
      navigate("/inbox");
      window.dispatchEvent(new Event("messy:inbox-read"));
    } catch {
      toast.error("Failed to mark as unread");
    }
  }

  function formatTime(dateStr: string | null) {
    return timeAgo(dateStr);
  }

  return (
    <div className="flex flex-col md:flex-row h-full">
      {/* Left panel: Conversation list */}
      <div className="w-full md:w-80 border-r flex flex-col bg-card">
        <div className="border-b">
          <div className="px-3 pt-3">
            <Tabs value={sourceFilter} onValueChange={(v) => setSourceFilter(v as "" | "widget" | "email")}>
              <TabsList className="w-full">
                <TabsTrigger value="" className="flex-1 gap-1.5">
                  <Inbox className="h-3.5 w-3.5" /> All
                </TabsTrigger>
                <TabsTrigger value="widget" className="flex-1 gap-1.5">
                  <MessageCircle className="h-3.5 w-3.5" /> Chat
                </TabsTrigger>
                <TabsTrigger value="email" className="flex-1 gap-1.5">
                  <Mail className="h-3.5 w-3.5" /> Email
                </TabsTrigger>
              </TabsList>
            </Tabs>
          </div>

          {/* Operator filter dropdown + search */}
          <div className="p-3 space-y-2">
            <div className="relative" ref={filterMenuRef}>
              <button
                onClick={() => setShowFilterMenu(!showFilterMenu)}
                className="w-full flex items-center gap-2.5 px-2.5 py-2 rounded-lg border hover:bg-muted transition-colors text-left"
              >
                {filter === "mine" && user ? (
                  <>
                    {currentOperator?.operator_profile?.avatar_url ? (
                      <img src={currentOperator.operator_profile.avatar_url} alt={user.name} className="w-6 h-6 rounded-full object-cover shrink-0" />
                    ) : (
                      <div className="w-6 h-6 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                        <span className="text-[10px] font-semibold text-primary">{user.name?.charAt(0)?.toUpperCase()}</span>
                      </div>
                    )}
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-medium truncate">{currentOperator?.operator_profile?.public_name || user.name}</div>
                      <div className="text-[11px] text-muted-foreground font-mono truncate">{user.email}</div>
                    </div>
                  </>
                ) : filter === "unassigned" ? (
                  <>
                    <div className="w-6 h-6 rounded-full bg-muted flex items-center justify-center shrink-0">
                      <User className="h-3 w-3 text-muted-foreground" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-medium">Unassigned</div>
                    </div>
                  </>
                ) : (
                  <>
                    <div className="w-6 h-6 rounded-full bg-muted flex items-center justify-center shrink-0">
                      <User className="h-3 w-3 text-muted-foreground" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-medium">All operators</div>
                    </div>
                  </>
                )}
                {filterCounts[filter] > 0 && (
                  <Badge variant="default" className="text-[10px] px-1.5 py-0 leading-4 shrink-0">
                    {filterCounts[filter]}
                  </Badge>
                )}
                <ChevronDown className="h-3.5 w-3.5 text-muted-foreground shrink-0" />
              </button>

              {showFilterMenu && (
                <div className="absolute left-0 right-0 top-full mt-1 bg-card border rounded-lg shadow-lg z-20 py-1">
                  {user && (
                    <button
                      className={`w-full flex items-center gap-2.5 px-3 py-2 text-left hover:bg-muted ${filter === "mine" ? "bg-muted" : ""}`}
                      onClick={() => { setFilter("mine"); setShowFilterMenu(false); }}
                    >
                      {currentOperator?.operator_profile?.avatar_url ? (
                        <img src={currentOperator.operator_profile.avatar_url} alt={user.name} className="w-6 h-6 rounded-full object-cover shrink-0" />
                      ) : (
                        <div className="w-6 h-6 rounded-full bg-primary/10 flex items-center justify-center shrink-0">
                          <span className="text-[10px] font-semibold text-primary">{user.name?.charAt(0)?.toUpperCase()}</span>
                        </div>
                      )}
                      <div className="flex-1 min-w-0">
                        <div className="text-sm font-medium truncate">{currentOperator?.operator_profile?.public_name || user.name}</div>
                        <div className="text-[11px] text-muted-foreground font-mono truncate">{user.email}</div>
                      </div>
                      {filterCounts.mine > 0 && (
                        <Badge variant="default" className="text-[10px] px-1.5 py-0 leading-4 shrink-0">{filterCounts.mine}</Badge>
                      )}
                      {filter === "mine" && <Check className="h-3.5 w-3.5 text-primary shrink-0" />}
                    </button>
                  )}
                  <button
                    className={`w-full flex items-center gap-2.5 px-3 py-2 text-left hover:bg-muted ${filter === "unassigned" ? "bg-muted" : ""}`}
                    onClick={() => { setFilter("unassigned"); setShowFilterMenu(false); }}
                  >
                    <div className="w-6 h-6 rounded-full bg-muted flex items-center justify-center shrink-0">
                      <User className="h-3 w-3 text-muted-foreground" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-medium">Unassigned</div>
                    </div>
                    {filterCounts.unassigned > 0 && (
                      <Badge variant="default" className="text-[10px] px-1.5 py-0 leading-4 shrink-0">{filterCounts.unassigned}</Badge>
                    )}
                    {filter === "unassigned" && <Check className="h-3.5 w-3.5 text-primary shrink-0" />}
                  </button>
                  <button
                    className={`w-full flex items-center gap-2.5 px-3 py-2 text-left hover:bg-muted ${filter === "all" ? "bg-muted" : ""}`}
                    onClick={() => { setFilter("all"); setShowFilterMenu(false); }}
                  >
                    <div className="w-6 h-6 rounded-full bg-muted flex items-center justify-center shrink-0">
                      <User className="h-3 w-3 text-muted-foreground" />
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="text-sm font-medium">All operators</div>
                    </div>
                    {filterCounts.all > 0 && (
                      <Badge variant="default" className="text-[10px] px-1.5 py-0 leading-4 shrink-0">{filterCounts.all}</Badge>
                    )}
                    {filter === "all" && <Check className="h-3.5 w-3.5 text-primary shrink-0" />}
                  </button>
                </div>
              )}
            </div>

            <div className="flex gap-1">
              {([
                ["", "Open"],
                ["resolved", "Resolved"],
                ["closed", "Closed"],
              ] as const).map(([val, label]) => (
                <button
                  key={val}
                  onClick={() => setStatusFilter(val)}
                  className={`px-2 py-0.5 text-[11px] rounded-full border transition-colors ${
                    statusFilter === val
                      ? "bg-primary text-primary-foreground border-primary"
                      : "text-muted-foreground border-border hover:border-gray-300"
                  }`}
                >
                  {label}
                </button>
              ))}
            </div>

            <div className="relative">
              <Search className="absolute left-2 top-2 h-4 w-4 text-muted-foreground" />
              <Input
                placeholder="Search..."
                value={searchInput}
                onChange={(e) => setSearchInput(e.target.value)}
                className="pl-8 h-8 text-sm"
              />
            </div>
          </div>
        </div>

        <div className="flex-1 overflow-y-auto p-2 space-y-1">
          {loading ? (
            <div className="p-4 text-center text-sm text-muted-foreground">Loading...</div>
          ) : conversations.length === 0 ? (
            <div className="p-4 text-center text-sm text-muted-foreground">No conversations</div>
          ) : (
            conversations.map((c) => (
              <div
                key={c.id}
                onClick={() => navigate(`/inbox/${c.id}`)}
                className={`p-2.5 rounded-xl cursor-pointer transition-colors ${
                  activeConversation?.id === c.id ? "bg-accent" : "hover:bg-muted"
                }`}
              >
                <div className="flex gap-2.5">
                  <div className="relative shrink-0 mt-0.5">
                    {c.source === "email" ? (
                      <div className="w-8 h-8 rounded-full bg-muted flex items-center justify-center">
                        <Mail className="h-4 w-4 text-muted-foreground" />
                      </div>
                    ) : c.ticket_number ? (
                      <div className="w-8 h-8 rounded-full bg-accent flex items-center justify-center">
                        <MessageCircle className="h-4 w-4 text-primary" />
                      </div>
                    ) : (
                      <>
                        <div className="w-8 h-8 rounded-full bg-muted flex items-center justify-center">
                          <span className="text-xs font-semibold text-muted-foreground">
                            {(c.visitor_name || "V").charAt(0).toUpperCase()}
                          </span>
                        </div>
                        <span
                          className={`absolute -bottom-0.5 -right-0.5 w-2.5 h-2.5 rounded-full border-2 border-white ${
                            c.visitor_online ? "bg-green-400" : "bg-gray-300"
                          }`}
                        />
                      </>
                    )}
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between mb-0.5">
                      {c.source === "email" ? (
                        <span className="font-medium text-sm truncate">
                          <span className="text-muted-foreground font-mono font-semibold">{ticketNum(c.ticket_number)}</span>
                          {c.subject && <span className="text-foreground ml-1.5">{c.subject}</span>}
                        </span>
                      ) : c.ticket_number ? (
                        <span className="font-medium text-sm truncate">
                          <span className="text-primary font-mono font-semibold">{ticketNum(c.ticket_number)}</span>
                          <span className="text-foreground ml-1.5">{c.visitor_name || "Visitor"}</span>
                        </span>
                      ) : (
                        <span className="font-medium text-sm truncate">{c.visitor_name || "Visitor"}</span>
                      )}
                      <div className="flex items-center gap-1.5 shrink-0 ml-2">
                        {c.unread_count > 0 && (
                          <Badge variant="default" className="text-[10px] px-1.5 py-0 leading-4">
                            {c.unread_count}
                          </Badge>
                        )}
                        <span className="text-xs text-muted-foreground">{formatTime(c.last_message_at)}</span>
                      </div>
                    </div>
                    <p className="text-xs text-muted-foreground truncate">
                      {c.source === "email"
                        ? <span className="font-mono">{c.visitor_email || c.last_message_preview || "No messages"}</span>
                        : c.last_message_preview || "No messages"}
                    </p>
                    {c.tags.length > 0 && (
                      <div className="flex items-center gap-1 mt-1">
                        {c.tags.map((t) => (
                          <span
                            key={t.id}
                            className="text-xs px-1.5 rounded"
                            style={tagStyle(t.name)}
                          >
                            {t.name}
                          </span>
                        ))}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

      {/* Center panel: Messages */}
      <div className="flex-1 flex flex-col bg-card">
        {activeConversation ? (
          <>
            <div className="p-3 border-b flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="relative shrink-0">
                  {activeConversation.source === "email" ? (
                    <div className="w-9 h-9 rounded-full bg-muted flex items-center justify-center">
                      <Mail className="h-5 w-5 text-muted-foreground" />
                    </div>
                  ) : activeConversation.ticket_number ? (
                    <div className="w-9 h-9 rounded-full bg-accent flex items-center justify-center">
                      <MessageCircle className="h-5 w-5 text-primary" />
                    </div>
                  ) : (
                    <>
                      <div className="w-9 h-9 rounded-full bg-muted flex items-center justify-center">
                        <span className="text-sm font-semibold text-muted-foreground">
                          {(activeConversation.visitor_name || "V").charAt(0).toUpperCase()}
                        </span>
                      </div>
                      <span
                        className={`absolute -bottom-0.5 -right-0.5 w-3 h-3 rounded-full border-2 border-white ${
                          customer?.online ? "bg-green-400" : "bg-gray-300"
                        }`}
                      />
                    </>
                  )}
                </div>
                <div>
                  <h3 className="font-semibold text-sm">
                    {activeConversation.source === "email" ? (
                      <>{activeConversation.ticket_number && <span className="text-muted-foreground font-mono">{ticketNum(activeConversation.ticket_number)} </span>}{activeConversation.subject || activeConversation.visitor_name}</>
                    ) : activeConversation.ticket_number ? (
                      <><span className="text-primary font-mono">{ticketNum(activeConversation.ticket_number)} </span>{activeConversation.visitor_name}</>
                    ) : activeConversation.visitor_name}
                  </h3>
                  <span className="text-xs text-muted-foreground">
                    {activeConversation.assigned_user && (
                      <span className="text-muted-foreground">{activeConversation.assigned_user.name}</span>
                    )}
                    {activeConversation.assigned_user && " · "}
                    <span className="font-mono">{activeConversation.visitor_email || "Anonymous"}</span>
                  </span>
                </div>
              </div>
              <div className="flex items-center gap-2">
                {/* Assign dropdown — shows avatar */}
                <div className="relative" ref={assignMenuRef}>
                  <Button size="sm" variant="outline" className="gap-1.5" onClick={() => setShowAssignMenu(!showAssignMenu)}>
                    {activeConversation.assigned_user ? (
                      (() => {
                        const assignedOp = operators.find((o) => o.id === activeConversation.assigned_user?.id);
                        return assignedOp?.operator_profile?.avatar_url ? (
                          <img src={assignedOp.operator_profile.avatar_url} alt={activeConversation.assigned_user.name} className="w-5 h-5 rounded-full object-cover" />
                        ) : (
                          <div className="w-5 h-5 rounded-full bg-primary/10 flex items-center justify-center">
                            <span className="text-[9px] font-semibold text-primary">{activeConversation.assigned_user.name.charAt(0).toUpperCase()}</span>
                          </div>
                        );
                      })()
                    ) : (
                      <User className="h-3.5 w-3.5 text-muted-foreground" />
                    )}
                    <span className="text-xs">{activeConversation.assigned_user?.name || "Unassigned"}</span>
                    <ChevronDown className="h-3 w-3 text-muted-foreground" />
                  </Button>
                  {showAssignMenu && (
                    <div className="absolute right-0 top-full mt-1 w-64 bg-card border rounded-lg shadow-lg z-20 py-1">
                      {operators.map((op) => (
                        <button
                          key={op.id}
                          className={`w-full text-left px-3 py-2 hover:bg-muted flex items-center gap-3 ${
                            activeConversation.assigned_user?.id === op.id ? "bg-muted" : ""
                          }`}
                          onClick={() => handleAssign(op.id)}
                        >
                          {op.operator_profile?.avatar_url ? (
                            <img src={op.operator_profile.avatar_url} alt={op.name} className="w-7 h-7 rounded-full object-cover shrink-0" />
                          ) : (
                            <div className="w-7 h-7 rounded-full bg-muted flex items-center justify-center shrink-0">
                              <span className="text-xs font-semibold text-muted-foreground">{op.name.charAt(0).toUpperCase()}</span>
                            </div>
                          )}
                          <div className="flex-1 min-w-0">
                            <div className="text-sm font-medium truncate">{op.operator_profile?.public_name || op.name}</div>
                            <div className="text-xs font-mono text-muted-foreground truncate">{op.email}</div>
                          </div>
                          {activeConversation.assigned_user?.id === op.id && (
                            <Check className="h-3.5 w-3.5 text-primary shrink-0" />
                          )}
                        </button>
                      ))}
                    </div>
                  )}
                </div>

                {/* Actions dropdown */}
                <div className="relative" ref={actionsMenuRef}>
                  <Button size="sm" variant="ghost" onClick={() => setShowActionsMenu(!showActionsMenu)}>
                    <MoreHorizontal className="h-4 w-4" />
                  </Button>
                  {showActionsMenu && (
                    <div className="absolute right-0 top-full mt-1 w-48 bg-card border rounded-lg shadow-lg z-20 py-1">
                      {activeConversation.status !== "resolved" && activeConversation.status !== "closed" && (
                        <button
                          className="w-full text-left px-3 py-2 text-sm hover:bg-muted flex items-center gap-2"
                          onClick={() => { handleStatusChange("resolved", "Marked as resolved"); setShowActionsMenu(false); }}
                        >
                          <CheckCircle2 className="h-4 w-4 text-green-600" />
                          Resolve
                        </button>
                      )}
                      {activeConversation.status !== "closed" && (
                        <button
                          className="w-full text-left px-3 py-2 text-sm hover:bg-muted flex items-center gap-2"
                          onClick={() => { handleStatusChange("closed", "Ticket closed"); setShowActionsMenu(false); }}
                        >
                          <Archive className="h-4 w-4 text-muted-foreground" />
                          Close
                        </button>
                      )}
                      {(activeConversation.status === "resolved" || activeConversation.status === "closed") && (
                        <button
                          className="w-full text-left px-3 py-2 text-sm hover:bg-muted flex items-center gap-2"
                          onClick={() => { handleStatusChange("open", "Reopened"); setShowActionsMenu(false); }}
                        >
                          <RotateCcw className="h-4 w-4 text-amber-600" />
                          Reopen
                        </button>
                      )}
                      <div className="border-t my-1" />
                      <button
                        className="w-full text-left px-3 py-2 text-sm hover:bg-muted flex items-center gap-2"
                        onClick={() => { handleMarkUnread(); setShowActionsMenu(false); }}
                      >
                        <EyeOff className="h-4 w-4 text-muted-foreground" />
                        Mark as unread
                      </button>
                    </div>
                  )}
                </div>
              </div>
            </div>

            <div
              className="flex-1 overflow-y-auto p-4 space-y-2"
              style={{ backgroundColor: widgetColors?.secondary_color || '#F9FAFB' }}
            >
              {messages.map((msg) => {
                const isOperator = msg.sender_type === "User";
                const isSystem = msg.sender_type === "System";
                const isNote = msg.private;
                const isEmail = activeConversation.source === "email";

                if (isSystem) {
                  return (
                    <div key={msg.id} className="text-center my-1">
                      <span className="text-[12px] text-muted-foreground italic">{msg.content}</span>
                    </div>
                  );
                }

                /* ── Email-style card rendering ── */
                if (isEmail && !isNote) {
                  return (
                    <div key={msg.id} className="mb-3">
                      <div className="bg-card border rounded-lg overflow-hidden shadow-sm">
                        <div className={`px-4 py-2.5 border-b text-xs flex items-center justify-between ${isOperator ? "bg-accent/60" : "bg-muted"}`}>
                          <div>
                            <span className="font-medium text-foreground">{msg.sender_name}</span>
                            {msg.metadata?.email && <span className="text-muted-foreground font-mono ml-1.5">&lt;{activeConversation.visitor_email}&gt;</span>}
                          </div>
                          <span className="text-muted-foreground">
                            {new Date(msg.created_at).toLocaleString([], { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" })}
                          </span>
                        </div>
                        <div className="p-4 text-sm leading-relaxed whitespace-pre-wrap">
                          {msg.content}
                        </div>
                        {msg.attachments?.length > 0 && (
                          <div className="px-4 pb-3 flex flex-wrap gap-2">
                            {msg.attachments.map((att) => {
                              const isImage = att.content_type?.startsWith("image/");
                              if (isImage) {
                                return (
                                  <a key={att.id} href={att.url} target="_blank" rel="noopener">
                                    <img src={att.url} alt={att.filename} className="max-w-[200px] rounded border" />
                                  </a>
                                );
                              }
                              const ext = att.filename?.split(".").pop()?.toUpperCase() || "FILE";
                              return (
                                <a key={att.id} href={att.url} target="_blank" rel="noopener" className="flex items-center gap-2 px-2 py-1.5 rounded border bg-muted text-xs">
                                  <span className="bg-muted text-muted-foreground rounded px-1.5 py-0.5 text-[10px] font-bold">{ext}</span>
                                  <span className="truncate max-w-[150px]">{att.filename}</span>
                                  <Download className="h-3 w-3 shrink-0 opacity-50" />
                                </a>
                              );
                            })}
                          </div>
                        )}
                      </div>
                    </div>
                  );
                }

                return (
                  <div
                    key={msg.id}
                    className={`flex ${isOperator ? "justify-end" : "justify-start"}`}
                  >
                    <div className={`max-w-[75%] ${isNote ? "border-l-2 border-yellow-400 bg-yellow-50" : ""}`}>
                      {(!isOperator || isNote) && (
                        <div className={`text-[11px] text-muted-foreground mb-0.5 ${isOperator ? "text-right pr-1" : "pl-1"}`}>
                          {msg.sender_name}
                          {isNote && " (Note)"}
                        </div>
                      )}
                      <div
                        className={`px-3.5 py-2.5 text-sm leading-relaxed ${
                          isNote
                            ? "bg-yellow-50 rounded-2xl"
                            : isOperator
                            ? "rounded-[16px_16px_4px_16px]"
                            : "rounded-[4px_16px_16px_16px]"
                        }`}
                        style={
                          isNote ? undefined
                            : isOperator
                            ? { backgroundColor: widgetColors?.primary_color || '#3B82F6', color: widgetColors?.text_color || '#ffffff' }
                            : { backgroundColor: '#F3F4F6', color: '#1F2937' }
                        }
                      >
                        {msg.content}
                        {msg.attachments?.length > 0 && (
                          <div className="mt-1.5 space-y-1">
                            {msg.attachments.map((att) => {
                              const isImage = att.content_type?.startsWith("image/");
                              if (isImage) {
                                return (
                                  <a key={att.id} href={att.url} target="_blank" rel="noopener">
                                    <img src={att.url} alt={att.filename} className="max-w-[200px] rounded mt-1" />
                                  </a>
                                );
                              }
                              const ext = att.filename?.split(".").pop()?.toUpperCase() || "FILE";
                              return (
                                <a
                                  key={att.id}
                                  href={att.url}
                                  target="_blank"
                                  rel="noopener"
                                  className={`flex items-center gap-2 px-2 py-1.5 rounded text-xs ${isOperator ? "bg-white/10" : "bg-card border"}`}
                                >
                                  <span className="bg-muted text-muted-foreground rounded px-1.5 py-0.5 text-[10px] font-bold">{ext}</span>
                                  <span className="truncate flex-1">{att.filename}</span>
                                  <Download className="h-3 w-3 shrink-0 opacity-50" />
                                </a>
                              );
                            })}
                          </div>
                        )}
                      </div>
                      <div className={`text-[10px] text-muted-foreground mt-0.5 ${isOperator ? "text-right pr-1" : "pl-1"}`}>
                        {new Date(msg.created_at).toLocaleTimeString([], {
                          hour: "2-digit",
                          minute: "2-digit",
                        })}
                      </div>
                    </div>
                  </div>
                );
              })}
              <div ref={messagesEndRef} />
            </div>

            <div className="p-3 border-t">
              <Tabs value={isPrivate ? "note" : "reply"} onValueChange={(v) => setIsPrivate(v === "note")} className="mb-2">
                <TabsList className="h-7">
                  <TabsTrigger value="reply" className="text-xs px-3 h-6">Reply</TabsTrigger>
                  <TabsTrigger value="note" className="text-xs px-3 h-6">Note</TabsTrigger>
                </TabsList>
              </Tabs>
              {attachments.length > 0 && (
                <div className="flex flex-wrap gap-2 mb-2">
                  {attachments.map((att, i) =>
                    att.preview ? (
                      <div key={i} className="relative w-14 h-14 rounded border overflow-hidden group">
                        <img src={att.preview} alt={att.file.name} className="w-full h-full object-cover" />
                        <button
                          onClick={() => setAttachments((prev) => { prev[i].preview && URL.revokeObjectURL(prev[i].preview!); return prev.filter((_, j) => j !== i); })}
                          className="absolute -top-0.5 -right-0.5 bg-red-500 text-white rounded-full w-4 h-4 flex items-center justify-center text-[10px] opacity-0 group-hover:opacity-100"
                        >
                          <X className="h-2.5 w-2.5" />
                        </button>
                      </div>
                    ) : (
                      <div key={i} className="flex items-center gap-1 bg-muted rounded px-2 py-1 text-xs group">
                        <Paperclip className="h-3 w-3 text-muted-foreground" />
                        <span className="truncate max-w-[100px]">{att.file.name}</span>
                        <button
                          onClick={() => setAttachments((prev) => prev.filter((_, j) => j !== i))}
                          className="text-muted-foreground hover:text-red-500"
                        >
                          <X className="h-3 w-3" />
                        </button>
                      </div>
                    )
                  )}
                </div>
              )}
              <div className="flex items-start gap-1.5">
                <button
                  type="button"
                  onClick={() => fileInputRef.current?.click()}
                  className="p-1 text-muted-foreground hover:text-muted-foreground shrink-0 mt-1.5"
                  title="Attach file"
                >
                  <Paperclip className="h-4 w-4" />
                </button>
                <div className="flex-1 flex items-start border rounded-md focus-within:ring-1 focus-within:ring-ring px-2 py-1.5 gap-2">
                  <div className="w-6 h-6 rounded-full bg-muted flex items-center justify-center shrink-0 mt-0.5">
                    <span className="text-[10px] font-semibold text-muted-foreground">
                      {user?.name?.charAt(0)?.toUpperCase()}
                    </span>
                  </div>
                  <div className="relative flex-1">
                    <textarea
                      ref={replyInputRef}
                      value={messageText}
                      onChange={(e) => {
                        const val = e.target.value;
                        setMessageText(val);
                        const ta = e.target;
                        ta.style.height = "auto";
                        ta.style.height = Math.min(ta.scrollHeight, 120) + "px";
                        const cursor = ta.selectionStart;
                        const textBefore = val.slice(0, cursor);
                        const slashMatch = textBefore.match(/(?:^|\s)\/([\w-]*)$/);
                        if (slashMatch) {
                          setCannedQuery(slashMatch[1]);
                        } else {
                          setCannedQuery(null);
                        }
                      }}
                      onKeyDown={(e) => {
                        if (cannedQuery !== null && cannedResults.length > 0) {
                          if (e.key === "ArrowDown") { e.preventDefault(); setCannedIndex((i) => Math.min(i + 1, cannedResults.length - 1)); return; }
                          if (e.key === "ArrowUp") { e.preventDefault(); setCannedIndex((i) => Math.max(i - 1, 0)); return; }
                          if (e.key === "Enter" || e.key === "Tab") { e.preventDefault(); selectCannedResponse(cannedResults[cannedIndex]); return; }
                        }
                        if (e.key === "Escape" && cannedQuery !== null) { e.preventDefault(); setCannedQuery(null); return; }
                        if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); handleSend(); }
                      }}
                      rows={1}
                      placeholder={isPrivate ? "Add an internal note..." : 'Type a reply... (use / for canned responses)'}
                      className="w-full text-sm resize-none outline-none overflow-hidden bg-transparent py-0.5"
                    />
                    {cannedQuery !== null && cannedResults.length > 0 && (
                      <div ref={cannedRef} className="absolute bottom-full left-0 mb-1 w-80 bg-card border rounded-lg shadow-lg z-20 max-h-60 overflow-y-auto">
                        {cannedResults.map((cr, i) => (
                          <button
                            key={cr.id}
                            type="button"
                            className={`w-full text-left px-3 py-2 text-sm hover:bg-muted border-b last:border-0 ${i === cannedIndex ? "bg-muted" : ""}`}
                            onMouseEnter={() => setCannedIndex(i)}
                            onClick={() => selectCannedResponse(cr)}
                          >
                            <span className="font-medium text-primary">{cr.shortcut.startsWith("/") ? cr.shortcut : `/${cr.shortcut}`}</span>
                            <span className="text-muted-foreground mx-1.5">—</span>
                            <span className="text-muted-foreground">{cr.title}</span>
                            <p className="text-xs text-muted-foreground truncate mt-0.5">{cr.content}</p>
                          </button>
                        ))}
                      </div>
                    )}
                  </div>
                  <div className="relative shrink-0 mt-0.5" ref={emojiRef}>
                    <button
                      type="button"
                      onClick={() => setShowEmoji(!showEmoji)}
                      className="p-0.5 text-muted-foreground hover:text-muted-foreground"
                      title="Emoji"
                    >
                      <Smile className="h-4 w-4" />
                    </button>
                    {showEmoji && (
                      <div className="absolute bottom-7 right-0 bg-card border rounded-lg shadow-lg p-2 z-10 w-[288px]">
                        <div className="grid grid-cols-8 gap-0.5">
                          {["😀","😃","😄","😁","😅","😂","🤣","😊","😇","🙂","😉","😍","🥰","😘","😋","😎","🤔","🤗","😢","😭","😤","🥺","😱","🤯","👍","👎","👏","🤝","🙏","💪","✅","❌","❤️","🔥","⭐","💯","🎉","📦","💰","📋"].map((e) => (
                            <button
                              key={e}
                              type="button"
                              className="w-8 h-8 flex items-center justify-center text-lg hover:bg-muted rounded"
                              onClick={() => {
                                const ta = replyInputRef.current;
                                if (ta) {
                                  const start = ta.selectionStart;
                                  const end = ta.selectionEnd;
                                  const next = messageText.slice(0, start) + e + messageText.slice(end);
                                  setMessageText(next);
                                  requestAnimationFrame(() => { ta.selectionStart = ta.selectionEnd = start + e.length; ta.focus(); });
                                } else {
                                  setMessageText((prev) => prev + e);
                                }
                                setShowEmoji(false);
                              }}
                            >
                              {e}
                            </button>
                          ))}
                        </div>
                      </div>
                    )}
                  </div>
                </div>
                <Button onClick={handleSend} disabled={sending || (!messageText.trim() && attachments.length === 0)} size="sm" className="shrink-0 mt-0.5">
                  <Send className="h-4 w-4" />
                </Button>
              </div>
              <input
                ref={fileInputRef}
                type="file"
                multiple
                accept="image/*,.pdf,.doc,.docx,.xls,.xlsx"
                className="hidden"
                onChange={(e) => {
                  const files = Array.from(e.target.files || []);
                  const newAtts = files.map((f) => ({
                    file: f,
                    preview: f.type.startsWith("image/") ? URL.createObjectURL(f) : null,
                  }));
                  setAttachments((prev) => [...prev, ...newAtts]);
                  e.target.value = "";
                }}
              />
            </div>
          </>
        ) : (
          <div className="flex-1 flex items-center justify-center text-muted-foreground">
            <div className="text-center">
              <MessageCircle className="h-12 w-12 mx-auto mb-2 opacity-30" />
              <p className="text-sm">Select a conversation</p>
            </div>
          </div>
        )}
      </div>

      {/* Right panel: Context */}
      {activeConversation && customer && (
        <div className="w-full md:w-72 border-l bg-muted overflow-y-auto">
          {/* Email ticket info */}
          {activeConversation.source === "email" && activeConversation.email_thread && (
            <div className="px-4 py-3 border-b">
              <h4 className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider mb-2">Ticket</h4>
              <div className="space-y-1.5 text-xs">
                <div className="flex items-center justify-between">
                  <span className="font-mono font-semibold text-muted-foreground">{ticketNum(activeConversation.email_thread.ticket_number)}</span>
                  <Badge variant="outline" className="text-[10px]">{activeConversation.status}</Badge>
                </div>
                <p className="text-muted-foreground">{activeConversation.email_thread.mailbox_name}</p>
              </div>
            </div>
          )}

          {/* Chat ticket info (offline form) */}
          {activeConversation.source === "widget" && activeConversation.ticket_number && (
            <div className="px-4 py-3 border-b">
              <h4 className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider mb-2">Ticket</h4>
              <div className="space-y-1.5 text-xs">
                <div className="flex items-center justify-between">
                  <span className="font-mono font-semibold text-primary">{ticketNum(activeConversation.ticket_number)}</span>
                  <Badge variant="outline" className="text-[10px]">{activeConversation.status}</Badge>
                </div>
                <p className="text-muted-foreground">via Chat Widget</p>
              </div>
            </div>
          )}

          {/* Sender / Visitor info */}
          <div className="px-4 py-3 border-b">
            <h4 className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider mb-2">
              {activeConversation.source === "email" ? "Sender" : "Visitor"}
            </h4>
            <div className="space-y-1 text-xs">
              <p className="font-medium text-foreground">{activeConversation.visitor_name}</p>
              <p className="font-mono text-muted-foreground break-all">{activeConversation.visitor_email || "\u2014"}</p>
              {customer.country && (
                <p className="text-muted-foreground">{customer.country}</p>
              )}
              {activeConversation.source !== "email" && customer.browser && (
                <p className="text-muted-foreground">{customer.browser}</p>
              )}
            </div>
          </div>

          {/* CC recipients */}
          {activeConversation.source === "email" && activeConversation.email_thread?.cc_list.length > 0 && (
            <div className="px-4 py-3 border-b">
              <h4 className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider mb-2">CC</h4>
              <div className="space-y-0.5">
                {activeConversation.email_thread.cc_list.map((cc, i) => (
                  <p key={i} className="text-xs font-mono text-muted-foreground break-all">{cc}</p>
                ))}
              </div>
            </div>
          )}

          {/* Recent Pages (chat only) */}
          {customer.recent_pages?.length > 0 && (
            <div className="px-4 py-3 border-b">
              <h4 className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider mb-2">Recent Pages</h4>
              <div className="space-y-1.5">
                {customer.recent_pages.map((page: any, i: number) => {
                  let pathname = "/";
                  try { pathname = new URL(page.url).pathname; } catch { /* ignore */ }
                  return (
                    <div key={i}>
                      <a href={page.url} target="_blank" rel="noopener" className="text-xs text-primary hover:underline break-all leading-tight block">
                        {page.title || pathname}
                      </a>
                      <span className="text-[10px] text-muted-foreground">{pathname} · {formatTime(page.visited_at)}</span>
                    </div>
                  );
                })}
              </div>
            </div>
          )}

          {customer.recent_pages?.length === 0 && activeConversation.visitor_page_url && (
            <div className="px-4 py-3 border-b">
              <h4 className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider mb-2">Current Page</h4>
              <a href={activeConversation.visitor_page_url} target="_blank" rel="noopener" className="text-xs text-primary hover:underline break-all">
                {activeConversation.visitor_page_title || activeConversation.visitor_page_url}
              </a>
            </div>
          )}

          {/* Tags */}
          {activeConversation.tags.length > 0 && (
            <div className="px-4 py-3 border-b">
              <h4 className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider mb-2">Tags</h4>
              <div className="flex flex-wrap gap-1">
                {activeConversation.tags.map((t) => (
                  <span key={t.id} className="text-xs px-2 py-0.5 rounded-full" style={tagStyle(t.name)}>
                    {t.name}
                  </span>
                ))}
              </div>
            </div>
          )}

          {/* Rating */}
          {activeConversation.rating && (
            <div className="px-4 py-3 border-b">
              <h4 className="text-[11px] font-semibold text-muted-foreground uppercase tracking-wider mb-2">Rating</h4>
              <p className="text-sm">{"★".repeat(activeConversation.rating)}{"☆".repeat(5 - activeConversation.rating)}</p>
              {activeConversation.rating_comment && (
                <p className="text-xs text-muted-foreground mt-1">{activeConversation.rating_comment}</p>
              )}
            </div>
          )}

          {/* View Customer */}
          {activeConversation.customer_id && (
            <div className="px-4 py-3">
              <Button
                variant="outline"
                size="sm"
                className="w-full"
                onClick={() => navigate(`/customers/${activeConversation.customer_id}`)}
              >
                <User className="h-3 w-3 mr-1" /> View Customer
              </Button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

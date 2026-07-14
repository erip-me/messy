import { h } from 'preact';
import { useState, useEffect, useRef, useCallback } from 'preact/hooks';
import type { MessyConfig, WidgetConfig, Conversation, Message } from './types';
import { initApi, getVisitorToken, fetchConfig, fetchConversations, fetchUnreadCount } from './services/api';
import { initCable, subscribeToPresence, sendPresenceHeartbeat, subscribeToWidgetConfig, subscribeToConversation } from './services/cable';
import { ChatButton } from './components/ChatButton';
import { ChatWindow } from './components/ChatWindow';

interface Props {
  config: MessyConfig;
}

export function Widget({ config: messyConfig }: Props) {
  const [widgetConfig, setWidgetConfig] = useState<WidgetConfig | null>(null);
  const [isOpen, setIsOpen] = useState(() => {
    try { return sessionStorage.getItem('messy_chat_open') === '1'; } catch { return false; }
  });
  const [conversation, setConversation] = useState<Conversation | null>(null);
  const [unreadCount, setUnreadCount] = useState(0);
  const isOpenRef = useRef(false);
  const onMessageRef = useRef<((msg: Message) => void) | null>(null);

  useEffect(() => {
    initApi(messyConfig.widgetId);

    console.log('[Messy] Fetching widget config...');
    fetchConfig()
      .then((cfg) => {
        setWidgetConfig(cfg);
        if (!cfg.settings.enabled) {
          console.warn('[Messy] Widget is disabled in settings — will not render');
          return;
        }
        console.log('[Messy] Config loaded, widget enabled');

        fetchConversations().then((res) => {
          const active = res.conversations.find((c) => c.status === 'open' || c.status === 'pending');
          if (active) setConversation(active);
        }).catch(() => {});

        fetchUnreadCount().then((res) => setUnreadCount(res.count)).catch(() => {});

        initCable(getVisitorToken(), messyConfig.widgetId);
        subscribeToPresence();

        // Track browsing history — debounced URL change detection
        let lastSentUrl = '';
        let debounceTimer: ReturnType<typeof setTimeout> | null = null;
        const sendPage = () => {
          if (debounceTimer) clearTimeout(debounceTimer);
          debounceTimer = setTimeout(() => {
            const url = window.location.href;
            if (url !== lastSentUrl) {
              lastSentUrl = url;
              sendPresenceHeartbeat(url, document.title);
            }
          }, 300);
        };

        // Send initial page after WS connects
        setTimeout(sendPage, 1000);

        // Detect navigation (popstate for back/forward, monkey-patch for SPA pushState)
        window.addEventListener('popstate', sendPage);
        const origPushState = history.pushState;
        const origReplaceState = history.replaceState;
        history.pushState = function (...args) {
          origPushState.apply(this, args);
          sendPage();
        };
        history.replaceState = function (...args) {
          origReplaceState.apply(this, args);
          sendPage();
        };

        subscribeToWidgetConfig(messyConfig.widgetId, (data: any) => {
          if (data.type === 'operator_count') {
            setWidgetConfig((prev) => prev ? { ...prev, operators_online: data.count, operators: data.operators } : prev);
          }
        });
      })
      .catch((err) => console.error('[Messy] Failed to load config — widget will not render. Check CORS and allowed_domains.', err));
  }, []);

  // Single subscription for the conversation — routes to ChatWindow or unread counter
  useEffect(() => {
    if (!conversation) return;
    console.log('[Messy] Widget subscribing to conversation', conversation.id);
    const sub = subscribeToConversation(conversation.id, (data: any) => {
      if (data.type === 'new_message') {
        console.log('[Messy] new_message received, chat open:', isOpenRef.current);
        if (onMessageRef.current) {
          onMessageRef.current(data.message);
        } else {
          setUnreadCount((c) => c + 1);
        }
      }
    });
    return () => sub.unsubscribe();
  }, [conversation?.id]);

  useEffect(() => {
    isOpenRef.current = isOpen;
    try { sessionStorage.setItem('messy_chat_open', isOpen ? '1' : '0'); } catch {}
    if (!isOpen && widgetConfig?.settings.enabled) {
      fetchUnreadCount().then((res) => setUnreadCount(res.count)).catch(() => {});
      const interval = setInterval(() => {
        fetchUnreadCount().then((res) => setUnreadCount(res.count)).catch(() => {});
      }, 30000);
      return () => clearInterval(interval);
    }
  }, [isOpen, widgetConfig?.settings.enabled]);

  if (!widgetConfig || !widgetConfig.settings.enabled) return null;

  const { settings, operators } = widgetConfig;

  return (
    <div>
      {isOpen ? (
        <ChatWindow
          config={widgetConfig}
          conversation={conversation}
          onConversationCreated={(conv) => {
            setConversation(conv);
            setUnreadCount(0);
          }}
          onClose={() => setIsOpen(false)}
          onMessageRef={onMessageRef}
        />
      ) : null}
      {!(isOpen && window.innerWidth <= 480) && <ChatButton
        onClick={() => {
          setIsOpen(!isOpen);
          if (!isOpen) setUnreadCount(0);
        }}
        unreadCount={isOpen ? 0 : unreadCount}
        operators={settings.show_operator_avatars ? operators : []}
        buttonColor={settings.button_color || settings.primary_color}
        buttonTextColor={settings.button_text_color || settings.text_color}
        position={settings.position}
      />}
    </div>
  );
}

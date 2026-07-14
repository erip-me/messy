import { h } from 'preact';
import { useState, useEffect, useRef } from 'preact/hooks';
import type { WidgetConfig, Conversation, Message } from '../types';
import { createConversation, fetchMessages, sendMessage, markRead, submitOfflineForm } from '../services/api';
import { MessageList } from './MessageList';
import { MessageInput } from './MessageInput';
import { TagButtons } from './TagButtons';
import { OfflineForm } from './OfflineForm';
import { OperatorAvatars } from './OperatorAvatars';

function LogoPlaceholder() {
  return (
    <div style={{
      width: '32px', height: '32px', borderRadius: '6px',
      backgroundColor: 'rgba(255,255,255,0.2)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
        <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
      </svg>
    </div>
  );
}

function HeaderLogo({ url }: { url: string | null }) {
  const [error, setError] = useState(false);
  useEffect(() => setError(false), [url]);

  if (!url || error) return <LogoPlaceholder />;

  return (
    <img
      src={url}
      alt=""
      style={{ width: '32px', height: '32px', borderRadius: '6px', objectFit: 'contain' }}
      onError={() => setError(true)}
    />
  );
}

interface Props {
  config: WidgetConfig;
  conversation: Conversation | null;
  onConversationCreated: (conv: Conversation) => void;
  onClose: () => void;
  onMessageRef: { current: ((msg: Message) => void) | null };
}

export function ChatWindow({ config, conversation, onConversationCreated, onClose, onMessageRef }: Props) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [hasMore, setHasMore] = useState(false);
  const [sending, setSending] = useState(false);
  const { settings, operators, tags, operators_online } = config;

  const isOffline = operators_online === 0 || !config.is_within_business_hours;

  // Register message handler so widget-level subscription routes messages here
  useEffect(() => {
    onMessageRef.current = (msg: Message) => {
      console.log('[Messy] ChatWindow received message:', msg);
      setMessages((prev) => {
        if (prev.find((m) => m.id === msg.id)) return prev;
        return [...prev, msg];
      });
      if (conversation) markRead(conversation.id, msg.id).catch(() => {});
    };
    return () => { onMessageRef.current = null; };
  }, [conversation?.id]);

  useEffect(() => {
    if (conversation) {
      loadMessages(conversation.id);
    }
  }, [conversation?.id]);

  async function loadMessages(convId: number) {
    setLoading(true);
    try {
      const res = await fetchMessages(convId);
      setMessages(res.messages);
      setHasMore(res.has_more);
      if (res.messages.length > 0) {
        markRead(convId, res.messages[res.messages.length - 1].id).catch(() => {});
      }
    } catch (e) {
      console.error('Failed to load messages', e);
    } finally {
      setLoading(false);
    }
  }

  async function loadOlderMessages() {
    if (!conversation || loadingMore || !hasMore || messages.length === 0) return;
    setLoadingMore(true);
    try {
      const oldest = messages[0];
      const res = await fetchMessages(conversation.id, oldest.id);
      setHasMore(res.has_more);
      if (res.messages.length > 0) {
        setMessages((prev) => [...res.messages, ...prev]);
      }
    } catch (e) {
      console.error('Failed to load older messages', e);
    } finally {
      setLoadingMore(false);
    }
  }

  async function handleSend(content: string) {
    if (!content.trim()) return;

    if (!conversation) {
      setSending(true);
      try {
        const res = await createConversation({
          initial_message: content,
          page_url: window.location.href,
          page_title: document.title,
        });
        onConversationCreated(res.conversation);
      } catch (e) {
        console.error('Failed to create conversation', e);
      } finally {
        setSending(false);
      }
      return;
    }

    setSending(true);
    try {
      const res = await sendMessage(conversation.id, content);
      setMessages((prev) => [...prev, res.message]);
    } catch (e) {
      console.error('Failed to send message', e);
    } finally {
      setSending(false);
    }
  }

  async function handleTagClick(tagId: number) {
    setSending(true);
    try {
      const tag = tags.find((t) => t.id === tagId);
      const res = await createConversation({
        initial_message: tag?.name || 'Hello',
        tag_id: tagId,
        page_url: window.location.href,
        page_title: document.title,
      });
      onConversationCreated(res.conversation);
    } catch (e) {
      console.error('Failed to create conversation', e);
    } finally {
      setSending(false);
    }
  }

  async function handleOfflineSubmit(name: string, email: string, message: string) {
    await submitOfflineForm({ name, email, message });
  }

  return (
    <div
      class="messy-chat-window"
      style={{
        position: 'fixed',
        ...(window.innerWidth <= 480
          ? { top: '0', bottom: '0', left: '0', right: '0' }
          : {
              bottom: '90px',
              [settings.position === 'bottom-left' ? 'left' : 'right']: '20px',
              width: '380px',
              maxHeight: '580px',
              height: 'auto',
            }),
        borderRadius: window.innerWidth <= 480 ? '0' : '16px',
        overflow: 'hidden',
        boxShadow: window.innerWidth <= 480 ? 'none' : '0 8px 32px rgba(0,0,0,0.15)',
        display: 'flex',
        flexDirection: 'column',
        backgroundColor: 'white',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
        zIndex: 2147483647,
      }}
    >
      {/* Header */}
      <div
        style={{
          backgroundColor: settings.header_color || settings.primary_color,
          color: settings.header_text_color || settings.text_color,
          padding: '14px 16px',
          display: 'flex',
          alignItems: 'center',
          gap: '10px',
          backgroundImage: settings.header_background_image_url ? `url(${settings.header_background_image_url})` : 'none',
          backgroundSize: 'cover',
          backgroundPosition: 'center',
          position: 'relative',
        }}
      >
        <HeaderLogo url={settings.logo_url} />
        <div style={{ flex: 1 }}>
          <div style={{ fontWeight: 'bold', fontSize: '15px' }}>{settings.title || 'Chat with us'}</div>
          <div style={{ fontSize: '11px', opacity: 0.8, marginTop: '1px' }}>
            {operators_online > 0
              ? `${operators_online} operator${operators_online > 1 ? 's' : ''} online`
              : 'We are currently offline'}
          </div>
        </div>
        <button
          onClick={onClose}
          style={{
            background: 'none',
            border: 'none',
            color: settings.header_text_color || settings.text_color,
            cursor: 'pointer',
            fontSize: '18px',
            padding: '4px',
            lineHeight: 1,
          }}
        >
          ✕
        </button>
      </div>

      {/* Body */}
      <div style={{
        flex: 1,
        overflow: 'auto',
        display: 'flex',
        flexDirection: 'column',
        backgroundColor: settings.secondary_color,
        backgroundImage: settings.chat_background_image_url ? `url(${settings.chat_background_image_url})` : 'none',
        backgroundSize: 'cover',
        backgroundPosition: 'center',
      }}>
        {isOffline && !conversation ? (
          <div style={{ padding: '20px' }}>
            <p style={{ color: '#6B7280', fontSize: '14px', marginBottom: '16px' }}>
              {settings.offline_message}
            </p>
            <OfflineForm onSubmit={handleOfflineSubmit} primaryColor={settings.primary_color} sendButtonColor={settings.send_button_color || undefined} sendButtonTextColor={settings.send_button_text_color || undefined} />
          </div>
        ) : !conversation ? (
          <div style={{ padding: '20px' }}>
            {settings.show_operator_avatars && operators.length > 0 && (
              <OperatorAvatars operators={operators} primaryColor={settings.primary_color} />
            )}
            <p style={{ color: '#374151', fontSize: '14px', margin: '16px 0' }}>
              {settings.greeting_message}
            </p>
            {tags.length > 0 && (
              <TagButtons tags={tags} onTagClick={handleTagClick} disabled={sending} />
            )}
          </div>
        ) : (
          <MessageList
            messages={messages}
            loading={loading}
            loadingMore={loadingMore}
            hasMore={hasMore}
            onLoadMore={loadOlderMessages}
            primaryColor={settings.primary_color}
            textColor={settings.text_color}
          />
        )}
      </div>

      {/* Input (shown when online or in active conversation) */}
      {(!isOffline || conversation) && (
        <MessageInput
          onSend={handleSend}
          onEscape={onClose}
          disabled={sending}
          placeholder={conversation ? 'Type a message...' : 'Type to start a conversation...'}
          primaryColor={settings.primary_color}
          sendButtonColor={settings.send_button_color || undefined}
          sendButtonTextColor={settings.send_button_text_color || undefined}
          autoFocus
        />
      )}
    </div>
  );
}

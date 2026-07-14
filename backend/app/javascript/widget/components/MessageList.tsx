import { h } from 'preact';
import { useEffect, useRef, useCallback } from 'preact/hooks';
import type { Message } from '../types';

const URL_REGEX = /https?:\/\/[^\s<>'")\]]+/g;

function linkify(text: string) {
  const parts: (string | h.JSX.Element)[] = [];
  let lastIndex = 0;
  let match: RegExpExecArray | null;

  URL_REGEX.lastIndex = 0;
  while ((match = URL_REGEX.exec(text)) !== null) {
    if (match.index > lastIndex) {
      parts.push(text.slice(lastIndex, match.index));
    }
    const url = match[0];
    parts.push(
      <a href={url} target="_blank" rel="noopener noreferrer" style={{ color: 'inherit', textDecoration: 'underline' }}>
        {url}
      </a>
    );
    lastIndex = URL_REGEX.lastIndex;
  }
  if (lastIndex < text.length) {
    parts.push(text.slice(lastIndex));
  }
  return parts.length > 0 ? parts : text;
}

interface Props {
  messages: Message[];
  loading: boolean;
  loadingMore: boolean;
  hasMore: boolean;
  onLoadMore: () => void;
  primaryColor: string;
  textColor: string;
}

export function MessageList({ messages, loading, loadingMore, hasMore, onLoadMore, primaryColor, textColor }: Props) {
  const containerRef = useRef<HTMLDivElement>(null);
  const bottomRef = useRef<HTMLDivElement>(null);
  const prevMessageCountRef = useRef(0);
  const prevScrollHeightRef = useRef(0);

  // Scroll to bottom instantly on initial load and new messages appended at the end
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    const prevCount = prevMessageCountRef.current;
    const newCount = messages.length;

    if (prevCount === 0 && newCount > 0) {
      // Initial load — jump to bottom
      container.scrollTop = container.scrollHeight;
    } else if (newCount > prevCount && prevCount > 0) {
      const lastMsg = messages[messages.length - 1];
      const firstOldMsg = messages[prevCount - 1];
      if (lastMsg && firstOldMsg && lastMsg.id > firstOldMsg.id) {
        // New message appended — scroll to bottom
        container.scrollTop = container.scrollHeight;
      }
    }

    prevMessageCountRef.current = newCount;
  }, [messages.length]);

  // When older messages are prepended, maintain scroll position
  useEffect(() => {
    const container = containerRef.current;
    if (!container || !loadingMore) return;

    // After prepend, restore position so it doesn't jump
    const newScrollHeight = container.scrollHeight;
    const addedHeight = newScrollHeight - prevScrollHeightRef.current;
    if (addedHeight > 0) {
      container.scrollTop += addedHeight;
    }
  }, [messages.length, loadingMore]);

  const handleScroll = useCallback(() => {
    const container = containerRef.current;
    if (!container || loadingMore || !hasMore) return;

    if (container.scrollTop < 60) {
      prevScrollHeightRef.current = container.scrollHeight;
      onLoadMore();
    }
  }, [loadingMore, hasMore, onLoadMore]);

  if (loading) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: '#9CA3AF' }}>
        Loading messages...
      </div>
    );
  }

  if (messages.length === 0) {
    return (
      <div style={{ padding: '40px', textAlign: 'center', color: '#9CA3AF', fontSize: '14px' }}>
        No messages yet. Say hello!
      </div>
    );
  }

  return (
    <div
      ref={containerRef}
      onScroll={handleScroll}
      style={{ padding: '12px 16px', flex: 1, overflowY: 'auto' }}
    >
      {loadingMore && (
        <div style={{ textAlign: 'center', padding: '8px', color: '#9CA3AF', fontSize: '12px' }}>
          Loading...
        </div>
      )}
      {messages.map((msg) => {
        const isOperator = msg.sender_type === 'User';
        const isSystem = msg.sender_type === 'System';

        if (isSystem) {
          return (
            <div key={msg.id} style={{ textAlign: 'center', margin: '8px 0' }}>
              <span style={{ fontSize: '12px', color: '#9CA3AF', fontStyle: 'italic' }}>
                {linkify(msg.content)}
              </span>
            </div>
          );
        }

        return (
          <div
            key={msg.id}
            style={{
              display: 'flex',
              justifyContent: isOperator ? 'flex-start' : 'flex-end',
              marginBottom: '8px',
            }}
          >
            <div style={{ maxWidth: '80%' }}>
              {isOperator && (
                <div style={{ fontSize: '11px', color: '#6B7280', marginBottom: '2px', paddingLeft: '4px' }}>
                  {msg.sender_name}
                </div>
              )}
              <div
                style={{
                  padding: '10px 14px',
                  borderRadius: isOperator ? '4px 16px 16px 16px' : '16px 16px 4px 16px',
                  backgroundColor: isOperator ? '#F3F4F6' : primaryColor,
                  color: isOperator ? '#1F2937' : textColor,
                  fontSize: '14px',
                  lineHeight: '1.4',
                  wordBreak: 'break-word',
                }}
              >
                {linkify(msg.content)}
                {msg.attachments?.length > 0 && (
                  <div style={{ marginTop: msg.content ? '8px' : '0' }}>
                    {msg.attachments.map((att) => {
                      const isImage = att.content_type?.startsWith('image/');
                      if (isImage) {
                        return (
                          <a key={att.id} href={att.url} target="_blank" rel="noopener" style={{ display: 'block', marginTop: '4px' }}>
                            <img src={att.url} alt={att.filename} style={{ maxWidth: '200px', borderRadius: '8px' }} />
                          </a>
                        );
                      }
                      return (
                        <a
                          key={att.id}
                          href={att.url}
                          target="_blank"
                          rel="noopener"
                          style={{
                            display: 'flex',
                            alignItems: 'center',
                            gap: '6px',
                            padding: '6px 10px',
                            marginTop: '4px',
                            borderRadius: '6px',
                            backgroundColor: isOperator ? '#E5E7EB' : 'rgba(255,255,255,0.15)',
                            color: isOperator ? '#1F2937' : textColor,
                            fontSize: '12px',
                            textDecoration: 'none',
                          }}
                        >
                          <span style={{ fontSize: '14px' }}>📎</span>
                          <span style={{ flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{att.filename}</span>
                        </a>
                      );
                    })}
                  </div>
                )}
              </div>
              <div
                style={{
                  fontSize: '10px',
                  color: '#9CA3AF',
                  marginTop: '2px',
                  textAlign: isOperator ? 'left' : 'right',
                  paddingLeft: '4px',
                  paddingRight: '4px',
                }}
              >
                {new Date(msg.created_at).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}
              </div>
            </div>
          </div>
        );
      })}
      <div ref={bottomRef} />
    </div>
  );
}

import type { WidgetConfig, Conversation, Message } from '../types';

let widgetId = '';

export function initApi(id: string) {
  widgetId = id;
}

function storageKey(): string {
  return `messy_visitor_token_${widgetId}`;
}

export function getVisitorToken(): string {
  let token = '';
  try {
    token = localStorage.getItem(storageKey()) || '';
  } catch {}
  if (!token) {
    token = crypto.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2)}`;
    try {
      localStorage.setItem(storageKey(), token);
    } catch {}
  }
  return token;
}

// Resolve API base from the script's own origin (widget JS is served from the same domain)
function getBaseUrl(): string {
  try {
    const scripts = document.querySelectorAll('script[src*="messy-widget"]');
    const src = scripts[scripts.length - 1]?.getAttribute('src');
    if (src) {
      const url = new URL(src, window.location.href);
      console.log('[Messy] API base URL resolved to:', url.origin);
      return url.origin;
    }
  } catch (e) {
    console.error('[Messy] Failed to resolve API base URL:', e);
  }
  console.warn('[Messy] Could not resolve API base URL from script src, falling back to empty string');
  return '';
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const base = getBaseUrl();
  const url = `${base}/widget/v1${path}`;

  let res: Response;
  try {
    res = await fetch(url, {
      ...options,
      credentials: 'include',
      headers: {
        'Content-Type': 'application/json',
        'X-Widget-Key': widgetId,
        'X-Visitor-Token': getVisitorToken(),
        ...((options.headers as Record<string, string>) || {}),
      },
    });
  } catch (e) {
    console.error(`[Messy] Network error fetching ${url} — this is likely a CORS or connectivity issue:`, e);
    throw e;
  }

  if (!res.ok) {
    const body = await res.text().catch(() => '');
    console.error(`[Messy] API ${options.method || 'GET'} ${path} returned ${res.status}: ${body}`);
    throw new Error(`API error: ${res.status}`);
  }

  return res.json();
}

export async function fetchConfig(): Promise<WidgetConfig> {
  return request('/config');
}

export async function fetchConversations(): Promise<{ conversations: Conversation[] }> {
  return request('/conversations');
}

export async function createConversation(params: {
  initial_message?: string;
  tag_id?: number;
  page_url?: string;
  page_title?: string;
}): Promise<{ conversation: Conversation }> {
  return request('/conversations', {
    method: 'POST',
    body: JSON.stringify(params),
  });
}

export async function fetchMessages(
  conversationId: number,
  before?: number
): Promise<{ messages: Message[]; has_more: boolean }> {
  const query = before ? `?before=${before}&limit=20` : '?limit=20';
  return request(`/conversations/${conversationId}/messages${query}`);
}

export async function sendMessage(
  conversationId: number,
  content: string
): Promise<{ message: Message }> {
  return request(`/conversations/${conversationId}/messages`, {
    method: 'POST',
    body: JSON.stringify({ content }),
  });
}

export async function markRead(conversationId: number, messageId: number): Promise<void> {
  await request(`/conversations/${conversationId}/read`, {
    method: 'POST',
    body: JSON.stringify({ message_id: messageId }),
  });
}

export async function rateConversation(
  conversationId: number,
  rating: number,
  comment?: string
): Promise<void> {
  await request(`/conversations/${conversationId}/rate`, {
    method: 'POST',
    body: JSON.stringify({ rating, comment }),
  });
}

export async function submitOfflineForm(params: {
  name: string;
  email: string;
  message: string;
}): Promise<void> {
  await request('/offline', {
    method: 'POST',
    body: JSON.stringify(params),
  });
}

export async function identify(params: {
  email: string;
  first_name?: string;
  last_name?: string;
  custom_attributes?: Record<string, unknown>;
  // HMAC-SHA256(secret, email) computed server-side by the embedding site.
  // Required when the widget has an identity_verification_secret configured;
  // without it any visitor could claim another customer's identity.
  user_hash?: string;
}): Promise<void> {
  await request('/identify', {
    method: 'POST',
    body: JSON.stringify(params),
  });
}

export async function fetchUnreadCount(): Promise<{ count: number }> {
  return request('/unread_count');
}

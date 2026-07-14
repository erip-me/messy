type MessageHandler = (data: any) => void;

interface Subscription {
  unsubscribe: () => void;
  send: (data: any) => void;
}

let ws: WebSocket | null = null;
let subscriptions: Map<string, MessageHandler> = new Map();
let wsUrl = '';
let visitorToken = '';
let widgetIdStr = '';

export function initCable(token: string, widgetId: string) {
  const scripts = document.querySelectorAll('script[src*="messy-widget"]');
  const src = scripts[scripts.length - 1]?.getAttribute('src');
  const origin = src ? new URL(src, window.location.href).origin : window.location.origin;
  wsUrl = origin.replace(/^http/, 'ws') + '/cable';
  visitorToken = token;
  widgetIdStr = widgetId;
  console.log('[Messy] initCable', { wsUrl, visitorToken, widgetId });
}

function connect() {
  if (ws && (ws.readyState === WebSocket.OPEN || ws.readyState === WebSocket.CONNECTING)) return;

  const url = `${wsUrl}?visitor_token=${visitorToken}&widget_key=${widgetIdStr}`;
  ws = new WebSocket(url);

  ws.onopen = () => {
    console.log('[Messy] WebSocket connected');
    // Re-subscribe to all channels
    subscriptions.forEach((_, identifier) => {
      sendSubscribe(identifier);
    });
  };

  ws.onerror = (e) => {
    console.error('[Messy] WebSocket error', e);
  };

  ws.onmessage = (event) => {
    const data = JSON.parse(event.data);
    if (data.type === 'ping') return;
    if (data.type === 'welcome') { console.log('[Messy] WebSocket welcome'); return; }
    if (data.type === 'confirm_subscription') { console.log('[Messy] Subscribed to', data.identifier); return; }
    if (data.type === 'reject_subscription') { console.warn('[Messy] Subscription rejected', data.identifier); return; }

    console.log('[Messy] WS message received:', JSON.stringify(data));

    if (data.identifier && data.message) {
      const handler = subscriptions.get(data.identifier);
      if (handler) {
        console.log('[Messy] Dispatching to handler for', data.identifier);
        handler(data.message);
      } else {
        console.warn('[Messy] No handler for identifier', data.identifier, 'registered:', Array.from(subscriptions.keys()));
      }
    }
  };

  ws.onclose = () => {
    // Reconnect after delay
    setTimeout(connect, 3000);
  };
}

function sendSubscribe(identifier: string) {
  if (ws?.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify({ command: 'subscribe', identifier }));
  }
}

export function subscribeToConversation(conversationId: number, handler: MessageHandler): Subscription {
  connect();
  const identifier = JSON.stringify({ channel: 'ConversationChannel', conversation_id: conversationId });
  subscriptions.set(identifier, handler);
  sendSubscribe(identifier);

  return {
    unsubscribe: () => {
      subscriptions.delete(identifier);
      if (ws?.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ command: 'unsubscribe', identifier }));
      }
    },
    send: (data: any) => {
      if (ws?.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ command: 'message', identifier, data: JSON.stringify(data) }));
      }
    },
  };
}

let presenceIdentifier = '';

export function sendPresenceHeartbeat(pageUrl: string, pageTitle: string) {
  if (ws?.readyState === WebSocket.OPEN && presenceIdentifier) {
    ws.send(JSON.stringify({
      command: 'message',
      identifier: presenceIdentifier,
      data: JSON.stringify({ action: 'heartbeat', page_url: pageUrl, page_title: pageTitle }),
    }));
  }
}

export function subscribeToPresence(): Subscription {
  console.log('[Messy] Subscribing to VisitorPresenceChannel');
  connect();
  const identifier = JSON.stringify({ channel: 'VisitorPresenceChannel' });
  presenceIdentifier = identifier;
  subscriptions.set(identifier, () => {});
  sendSubscribe(identifier);

  return {
    unsubscribe: () => {
      subscriptions.delete(identifier);
      if (ws?.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ command: 'unsubscribe', identifier }));
      }
    },
    send: (data: any) => {
      if (ws?.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ command: 'message', identifier, data: JSON.stringify(data) }));
      }
    },
  };
}

export function subscribeToWidgetConfig(accountId: string, handler: MessageHandler): Subscription {
  connect();
  const identifier = JSON.stringify({ channel: 'WidgetConfigChannel' });
  subscriptions.set(identifier, handler);
  sendSubscribe(identifier);

  return {
    unsubscribe: () => {
      subscriptions.delete(identifier);
    },
    send: () => {},
  };
}

export function disconnect() {
  if (ws) {
    ws.close();
    ws = null;
  }
  subscriptions.clear();
}

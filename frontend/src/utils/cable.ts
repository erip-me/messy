import { createConsumer } from "@rails/actioncable";
import { appSettings } from "./constants";

/**
 * Creates an ActionCable consumer with JWT auth via URL param.
 *
 * The URL is passed as a **function** so that ActionCable calls it on every
 * reconnection attempt, always picking up the latest token from localStorage
 * (which the token-refresh interceptor keeps fresh).
 *
 * Pass `onResync` to refetch over HTTP whatever was broadcast while the socket
 * was down: it runs after every reconnect (never the first connect) and when the
 * tab comes back to the foreground. The ingress closes WebSockets on config
 * changes, and ActionCable only reconnects and resubscribes; it does not replay.
 */
export function createAuthenticatedConsumer(onResync?: () => void) {
  if (!localStorage.getItem("messy_token")) return null;

  const getUrl = () => {
    const token = localStorage.getItem("messy_token");
    if (!token) return null;
    const apiUrl = appSettings.apiBaseUrl || "";
    let url = apiUrl.replace(/^http/, "ws") + "/cable?token=" + encodeURIComponent(token);
    // Operators can be working in a workspace other than their default, and a
    // WebSocket can't send X-Account-Id. The server verifies membership before
    // honouring it, so an unentitled id just falls back to the default workspace.
    const workspaceId = localStorage.getItem("messy_active_workspace");
    if (workspaceId) url += "&account_id=" + encodeURIComponent(workspaceId);
    return url;
  };

  const consumer = createConsumer(getUrl);
  if (onResync) addCatchUp(consumer, onResync);
  return consumer;
}

function addCatchUp(consumer: ReturnType<typeof createConsumer>, onResync: () => void) {
  // Coalesces the per-subscription connected() calls of one reconnect into one refetch.
  let timer: ReturnType<typeof setTimeout> | undefined;
  const resync = () => {
    clearTimeout(timer);
    timer = setTimeout(onResync, 100);
  };
  const onVisible = () => {
    if (document.visibilityState === "visible") resync();
  };
  document.addEventListener("visibilitychange", onVisible);

  // connected() fires once the server confirms the (re)subscription, so a refetch
  // started there cannot miss a broadcast that the socket would then also miss.
  const create = consumer.subscriptions.create.bind(consumer.subscriptions);
  consumer.subscriptions.create = (channel: any, mixin: any = {}) => {
    let connectedBefore = false;
    return create(channel, {
      ...mixin,
      connected(...args: any[]) {
        if (connectedBefore) resync();
        connectedBefore = true;
        return mixin.connected?.apply(this, args);
      },
    });
  };

  const disconnect = consumer.disconnect.bind(consumer);
  consumer.disconnect = () => {
    clearTimeout(timer);
    document.removeEventListener("visibilitychange", onVisible);
    disconnect();
  };
}

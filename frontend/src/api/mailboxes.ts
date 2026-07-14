import request from "../utils/request";

export type MailboxProvider = "imap" | "gmail" | "office365";

export interface Mailbox {
  id: number;
  name: string;
  email_address: string;
  provider: MailboxProvider;
  active: boolean;
  ticket_prefix: string;
  next_ticket_number: number;
  auto_assign: boolean;
  auto_reply_enabled: boolean;
  auto_reply_template: string | null;
  auto_close_days: number | null;
  notification_events: Record<string, boolean>;
  last_synced_at: string | null;
  environment_id: number;
  connected: boolean;
  push_active: boolean;
  created_at: string;
}

export function getMailboxes() {
  return request.get<{ mailboxes: Mailbox[] }>("/mailboxes");
}

export function getMailbox(id: number) {
  return request.get<{ mailbox: Mailbox }>(`/mailboxes/${id}`);
}

export function createMailbox(data: Partial<Mailbox> & { config?: Record<string, string> }) {
  return request.post<{ mailbox: Mailbox }>("/mailboxes", data);
}

export function updateMailbox(id: number, data: Partial<Mailbox> & { config?: Record<string, string>; notification_events?: Record<string, boolean> }) {
  return request.patch<{ mailbox: Mailbox }>(`/mailboxes/${id}`, data);
}

export function deleteMailbox(id: number) {
  return request.delete(`/mailboxes/${id}`);
}

export function testMailboxConnection(id: number) {
  return request.post<{ success: boolean; details?: Record<string, unknown>; error?: string }>(
    `/mailboxes/${id}/test_connection`
  );
}

// Returns the provider consent URL to redirect the browser to. The backend
// handles the OAuth callback server-side and redirects back to /helpdesk.
export function getMailboxOauthUrl(id: number) {
  return request.get<{ url: string }>(`/mailboxes/${id}/oauth_url`);
}

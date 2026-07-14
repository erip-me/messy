import request from '../utils/request';

export interface ConversationSummary {
  id: number;
  visitor_name: string;
  visitor_email: string | null;
  status: string;
  priority: string;
  source: "widget" | "api" | "email";
  subject: string | null;
  ticket_number: string | null;
  assigned_user: { id: number; name: string; avatar_url: string | null; online: boolean } | null;
  last_message_at: string | null;
  last_message_preview: string | null;
  visitor_last_seen_at: string | null;
  visitor_online: boolean;
  unread_count: number;
  tags: { id: number; name: string }[];
  created_at: string;
}

export interface EmailThread {
  ticket_number: string;
  from_email: string;
  from_name: string | null;
  subject: string | null;
  cc_list: string[];
  mailbox_name: string;
  mailbox_id: number;
}

export interface EmailDetail {
  html_body: string | null;
  text_body: string | null;
  from_email: string;
  from_name: string | null;
  to_email: string;
  cc_list: string[];
  message_id_header: string | null;
  created_at: string;
}

export interface ConversationDetail extends ConversationSummary {
  visitor_page_url: string | null;
  visitor_page_title: string | null;
  visitor_user_agent: string | null;
  visitor_ip: string | null;
  visitor_country: string | null;
  rating: number | null;
  rating_comment: string | null;
  first_response_at: string | null;
  resolved_at: string | null;
  snoozed_until: string | null;
  customer_id: number | null;
  environment_id: number;
  email_thread?: EmailThread;
}

export interface ChatMessage {
  id: number;
  conversation_id: number;
  sender_type: string;
  sender_id: number | null;
  sender_name: string;
  message_type: string;
  content: string;
  private: boolean;
  metadata: Record<string, unknown>;
  read_by_visitor: boolean;
  read_by_operator: boolean;
  attachments: { id: number; filename: string; content_type: string; byte_size: number; url: string }[];
  created_at: string;
}

export function getConversations(params: {
  status?: string;
  assigned_to?: string;
  source?: string;
  q?: string;
  page?: number;
  per_page?: number;
}) {
  return request.get<{
    conversations: ConversationSummary[];
    total: number;
    page: number;
    total_pages: number;
  }>('/conversations', { params });
}

export function getConversation(id: number) {
  return request.get<{
    conversation: ConversationDetail;
    messages: ChatMessage[];
    customer: Record<string, unknown> | null;
  }>(`/conversations/${id}`);
}

export function getConversationMessages(id: number, params?: { before?: number; limit?: number }) {
  return request.get<{ messages: ChatMessage[]; has_more: boolean }>(
    `/conversations/${id}/messages`,
    { params }
  );
}

export function sendConversationMessage(id: number, data: { content: string; private?: boolean; attachments?: File[] }) {
  if (data.attachments?.length) {
    const formData = new FormData();
    formData.append('content', data.content);
    if (data.private) formData.append('private', 'true');
    data.attachments.forEach((f) => formData.append('attachments[]', f));
    return request.post<{ message: ChatMessage }>(`/conversations/${id}/create_message`, formData);
  }
  return request.post<{ message: ChatMessage }>(`/conversations/${id}/create_message`, data);
}

export function updateConversation(id: number, data: { status?: string; priority?: string }) {
  return request.patch<{ conversation: ConversationDetail }>(`/conversations/${id}`, data);
}

export function markConversationRead(id: number) {
  return request.post(`/conversations/${id}/mark_read`);
}

export function markConversationUnread(id: number) {
  return request.post(`/conversations/${id}/mark_unread`);
}

export function assignConversation(id: number, userId: number) {
  return request.post<{ conversation: ConversationDetail }>(`/conversations/${id}/assign`, { user_id: userId });
}

export function transferConversation(id: number, userId: number, note?: string) {
  return request.post<{ conversation: ConversationDetail }>(`/conversations/${id}/transfer`, { user_id: userId, note });
}

export function snoozeConversation(id: number, until: string) {
  return request.post<{ conversation: ConversationDetail }>(`/conversations/${id}/snooze`, { until });
}

export function addConversationTag(id: number, tagId: number) {
  return request.post(`/conversations/${id}/add_tag`, { tag_id: tagId });
}

export function removeConversationTag(id: number, tagId: number) {
  return request.delete(`/conversations/${id}/tags/${tagId}`);
}

export function searchConversations(q: string) {
  return request.get<{ conversations: ConversationSummary[] }>('/conversations/search', { params: { q } });
}

export function getEmailDetail(conversationId: number, messageId: number) {
  return request.get<{ email_detail: EmailDetail | null }>(
    `/conversations/${conversationId}/email_detail`,
    { params: { message_id: messageId } }
  );
}

export function getConversationStats() {
  return request.get<{
    open: number;
    pending: number;
    snoozed: number;
    unread: number;
    unread_mine: number;
    unread_unassigned: number;
    resolved_today: number;
    avg_first_response_seconds: number | null;
  }>('/conversations/stats');
}

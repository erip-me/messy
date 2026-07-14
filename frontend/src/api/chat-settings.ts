import request from '../utils/request';

export interface WidgetSettings {
  enabled: boolean;
  title: string;
  logo_url: string | null;
  primary_color: string;
  secondary_color: string;
  text_color: string;
  button_color: string;
  button_text_color: string;
  header_color: string | null;
  header_text_color: string | null;
  send_button_color: string | null;
  send_button_text_color: string | null;
  header_background_image_url: string | null;
  chat_background_image_url: string | null;
  position: string;
  greeting_message: string;
  offline_message: string;
  require_email_before_chat: boolean;
  show_operator_avatars: boolean;
  show_operator_count: boolean;
  business_hours_enabled: boolean;
  business_hours: Record<string, { start: string; end: string }>;
  timezone: string;
  auto_close_hours: number;
  welcome_triggers: unknown[];
  allowed_domains: string[];
}

export interface ConversationTag {
  id: number;
  name: string;
  is_quick_reply: boolean;
  sort_order: number;
}

export interface CannedResponse {
  id: number;
  shortcut: string;
  title: string;
  content: string;
  created_by: string | null;
}

export interface OperatorProfile {
  id: number;
  public_name: string;
  bio: string | null;
  availability: string;
  auto_assign: boolean;
  max_concurrent_chats: number;
  avatar_url: string | null;
  online: boolean;
}

export function getChatSettings() {
  return request.get<{ chat_enabled: boolean; widget_settings: WidgetSettings; tags: ConversationTag[] }>('/chat_settings');
}

export function updateChatSettings(settings: Partial<WidgetSettings>) {
  return request.patch<{ chat_enabled: boolean; widget_settings: WidgetSettings }>('/chat_settings', { widget_settings: settings });
}

export function updateChatEnabled(enabled: boolean) {
  return request.patch<{ chat_enabled: boolean; widget_settings: WidgetSettings }>('/chat_settings', { chat_enabled: enabled });
}

export function uploadChatSettingsImage(field: string, file: File) {
  const formData = new FormData();
  formData.append(field, file);
  formData.append('widget_settings[enabled]', 'true');
  return request.patch<{ widget_settings: WidgetSettings }>('/chat_settings', formData);
}

export function removeChatSettingsImage(field: string) {
  const formData = new FormData();
  formData.append(`remove_${field}`, 'true');
  formData.append('widget_settings[enabled]', 'true');
  return request.patch<{ widget_settings: WidgetSettings }>('/chat_settings', formData);
}

export function getConversationTags() {
  return request.get<{ tags: ConversationTag[] }>('/conversation_tags');
}

export function createConversationTag(data: Partial<ConversationTag>) {
  return request.post<{ tag: ConversationTag }>('/conversation_tags', data);
}

export function updateConversationTag(id: number, data: Partial<ConversationTag>) {
  return request.patch<{ tag: ConversationTag }>(`/conversation_tags/${id}`, data);
}

export function deleteConversationTag(id: number) {
  return request.delete(`/conversation_tags/${id}`);
}

export function getCannedResponses(q?: string) {
  return request.get<{ canned_responses: CannedResponse[] }>('/canned_responses', { params: q ? { q } : {} });
}

export function createCannedResponse(data: Partial<CannedResponse>) {
  return request.post<{ canned_response: CannedResponse }>('/canned_responses', data);
}

export function updateCannedResponse(id: number, data: Partial<CannedResponse>) {
  return request.patch<{ canned_response: CannedResponse }>(`/canned_responses/${id}`, data);
}

export function deleteCannedResponse(id: number) {
  return request.delete(`/canned_responses/${id}`);
}

export interface OperatorProfileListItem {
  id: number;
  user_id: number;
  public_name: string;
  availability: string;
  auto_assign: boolean;
  max_concurrent_chats: number;
  sort_order: number;
  avatar_url: string | null;
  online: boolean;
}

export function getOperatorProfiles() {
  return request.get<{ operator_profiles: OperatorProfileListItem[] }>('/operator_profiles');
}

export function reorderOperatorProfiles(order: { id: number; sort_order: number }[]) {
  return request.patch('/operator_profiles/reorder', { order });
}

export function getOperatorProfile() {
  return request.get<{ operator_profile: OperatorProfile | null }>('/operator_profile');
}

export function updateOperatorProfile(data: Partial<OperatorProfile>) {
  return request.patch<{ operator_profile: OperatorProfile }>('/operator_profile', data);
}

export function uploadOperatorAvatar(file: File) {
  const formData = new FormData();
  formData.append('avatar', file);
  // Don't set Content-Type — the browser must set it with the multipart boundary
  return request.patch<{ operator_profile: OperatorProfile }>('/operator_profile', formData);
}

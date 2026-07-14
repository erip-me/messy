export interface MessyConfig {
  widgetId: string;
}

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
  is_within_business_hours: boolean;
}

export interface Operator {
  id: number;
  name: string;
  bio?: string;
  avatar_url?: string;
  online: boolean;
}

export interface Tag {
  id: number;
  name: string;
  color: string;
}

export interface Conversation {
  id: number;
  status: string;
  subject?: string;
  assigned_operator?: Operator;
  last_message_at?: string;
  last_message_preview?: string;
  unread_count: number;
  created_at: string;
}

export interface Message {
  id: number;
  conversation_id: number;
  sender_type: string;
  sender_id?: number;
  sender_name: string;
  message_type: string;
  content: string;
  private: boolean;
  attachments: Attachment[];
  created_at: string;
}

export interface Attachment {
  id: number;
  filename: string;
  content_type: string;
  byte_size: number;
  url: string;
}

export interface WidgetConfig {
  settings: WidgetSettings;
  operators_online: number;
  operators: Operator[];
  tags: Tag[];
  is_within_business_hours: boolean;
}

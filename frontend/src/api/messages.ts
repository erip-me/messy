import { headerJson } from "../utils/constants";
import request from "../utils/request";

export interface Message {
  id: number;
  to: string;
  cc?: string;
  bcc?: string;
  subject?: string;
  body: string;
  channel: 'email' | 'sms' | 'whatsapp' | 'push';
  status: 'pending' | 'sent' | 'delivered' | 'failed' | 'bounced' | 'expired' | 'rejected' | 'suppressed';
  environment: string;
  trigger?: string;
  template_name?: string;
  drip_campaign_id?: number | null;
  drip?: { id: number; name: string; step_position: number | null } | null;
  sending_identity?: { id: number; from_name: string | null; from_email: string } | null;
  tags?: any[];
  language?: string;
  sent_at?: string;
  delivered_at?: string;
  failed_at?: string;
  failure_reason?: string;
  created_at: string;
  updated_at: string;
  attachments?: MessageAttachment[];
  deliveries?: MessageDelivery[];
  child_messages?: ChildMessage[];
  opened_at?: string | null;
  open_count?: number;
  click_count?: number;
  link_clicks?: { url: string; count: number }[];
  customer?: {
    id: number;
    email: string;
    first_name: string | null;
    last_name: string | null;
    unsubscribed_channels?: Record<string, string | { at: string; reason: string }>;
  } | null;
}

export interface MessageAttachment {
  id: number;
  filename: string;
  content_type: string;
  byte_size: number;
  url: string;
}

export interface MessageDelivery {
  id: number;
  message_id: number;
  integration_id: number;
  recipient: string;
  started_at?: string;
  completed_at?: string;
  error?: string;
  status?: string;
  provider_message_id?: string;
  created_at: string;
  updated_at: string;
}

export interface ChildMessage {
  id: number;
  to: string;
  subject?: string;
  body: string;
  type: string;
  status: 'pending' | 'sent' | 'delivered' | 'failed' | 'bounced' | 'expired' | 'rejected' | 'suppressed';
  sent_at?: string;
  created_at: string;
  updated_at: string;
  deliveries?: MessageDelivery[];
}

export interface MessageFilters {
  to?: string;
  channel?: string;
  status?: string;
  environment?: string;
  date_from?: string;
  date_to?: string;
  search?: string;
  drip_id?: string;
  drip_step_id?: string;
}

export interface MessagesResponse {
  messages: Message[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

export interface SendMessageRequest {
  to: string;
  cc?: string;
  bcc?: string;
  subject?: string;
  body: string;
  channel: 'email' | 'sms' | 'whatsapp' | 'push';
  template_id?: number;
  sending_identity_id?: number | null;
  variables?: Record<string, any>;
  tags?: string[];
  language?: string;
  attachments?: File[];
}

export interface WhatsAppTemplateComponent {
  type: string;
  text?: string;
  buttons?: Array<{ type: string; text: string; url?: string }>;
}

export interface WhatsAppTemplate {
  id: string;
  name: string;
  status: string;
  category: string;
  language: string;
  components: WhatsAppTemplateComponent[];
}

export interface TriggerMessageRequest {
  trigger: string;
  to: string;
  channel?: string;
  data?: Record<string, any>;
  variables?: Record<string, any>;
}

const controller = "/messages";

export const getMessages = async (
  apiKey: string,
  page: number = 1,
  per_page: number = 20,
  filters?: MessageFilters
): Promise<MessagesResponse> => {
  const params = new URLSearchParams({
    page: page.toString(),
    per_page: per_page.toString(),
  });

  // Add filters to params if provided
  if (filters) {
    Object.entries(filters).forEach(([key, value]) => {
      if (value !== undefined && value !== null && value !== '') {
        params.append(key, value.toString());
      }
    });
  }

  const response = await request({
    url: `${controller}?${params.toString()}`,
    method: "GET",
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return response.data;
};

export const getMessageById = async (id: number, apiKey: string): Promise<Message> => {
  const response = await request({
    url: `${controller}/${id}`,
    method: "GET",
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return response.data;
};

export const sendMessage = async (data: SendMessageRequest, apiKey: string): Promise<Message> => {
  // Map frontend channel names to backend STI type names
  const channelToType: Record<string, string> = {
    email: "email",
    sms: "sms",
    whatsapp: "whatsapp",
    push: "mobile_push",
  };

  const { channel, attachments, ...messageFields } = data;

  if (attachments && attachments.length > 0) {
    const formData = new FormData();
    formData.append("type", channelToType[channel] || channel);
    for (const [key, value] of Object.entries(messageFields)) {
      if (value !== undefined && value !== null) {
        if (Array.isArray(value)) {
          value.forEach((v) => formData.append(`message[${key}][]`, String(v)));
        } else {
          formData.append(`message[${key}]`, String(value));
        }
      }
    }
    attachments.forEach((file) => formData.append("message[attachments][]", file));

    const response = await request({
      url: controller,
      method: "POST",
      data: formData,
      headers: {
        Authorization: `Bearer ${apiKey}`,
      },
    });
    return response.data;
  }

  const response = await request({
    url: controller,
    method: "POST",
    data: {
      type: channelToType[channel] || channel,
      message: messageFields,
    },
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return response.data;
};

export const retryMessage = async (id: number, apiKey: string): Promise<Message> => {
  const response = await request({
    url: `${controller}/${id}/retry_delivery`,
    method: "POST",
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return response.data;
};

export const triggerMessage = async (data: TriggerMessageRequest, apiKey: string): Promise<Message> => {
  const response = await request({
    url: `${controller}/trigger`,
    method: "POST",
    data,
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return response.data;
};

export const getWhatsAppTemplates = async (): Promise<WhatsAppTemplate[]> => {
  const response = await request.get('/whatsapp_templates');
  return response.data?.templates || [];
};
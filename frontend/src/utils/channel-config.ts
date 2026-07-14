export type Channel = "email" | "sms" | "whatsapp" | "push";

export interface ChannelDef {
  name: string;
  description: string;
  hasSubject: boolean;
  hasPreview: boolean;
  hasLayout: boolean;
  subjectLabel?: string;
  editorLanguage: string;
  maxLength?: number;
}

export const CHANNEL_CONFIG: Record<Channel, ChannelDef> = {
  email: {
    name: "Email",
    description: "Send emails with full rich content support",
    hasSubject: true,
    hasPreview: true,
    hasLayout: true,
    subjectLabel: "Subject",
    editorLanguage: "html",
  },
  sms: {
    name: "SMS",
    description: "Send text messages to phone numbers",
    hasSubject: false,
    hasPreview: false,
    hasLayout: false,
    editorLanguage: "plaintext",
    maxLength: 160,
  },
  whatsapp: {
    name: "WhatsApp",
    description: "Send WhatsApp messages using templates",
    hasSubject: false,
    hasPreview: false,
    hasLayout: false,
    editorLanguage: "plaintext",
  },
  push: {
    name: "Push Notification",
    description: "Send push notifications to device tokens",
    hasSubject: true,
    hasPreview: false,
    hasLayout: false,
    subjectLabel: "Title",
    editorLanguage: "plaintext",
  },
};

import { headerJson } from "../utils/constants";
import request from "../utils/request";

export interface DashboardStats {
  total_messages: number;
  total_templates: number;
  total_integrations: number;
  messages_this_month: number;
  messages_last_month: number;
  growth_percentage: number;
  recent_messages: {
    id: number;
    to: string;
    subject?: string;
    channel: string;
    status: string;
    sent_at?: string;
    created_at: string;
  }[];
  channel_breakdown: {
    email: number;
    sms: number;
    whatsapp: number;
    push: number;
  };
  status_breakdown: {
    pending: number;
    sent: number;
    delivered: number;
    failed: number;
    bounced: number;
  };
}

const controller = "/dashboard";

export const getDashboardStats = async (): Promise<DashboardStats> => {
  const response = await request({
    url: `${controller}/stats`,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};
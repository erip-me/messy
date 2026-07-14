import request from '@/utils/request';

export type CampaignStatus = 'draft' | 'sending' | 'sent' | 'failed';

export interface CampaignStats {
  total: number;
  sent: number;
  failed: number;
  pending: number;
  rejected: number;
  open_rate: number;
  unsubscribed: number;
}

export type CampaignChannel = 'email' | 'sms' | 'whatsapp' | 'push';

export interface Campaign {
  id: number;
  name: string;
  subject: string;
  from_email: string;
  content: string | null;
  channel: CampaignChannel;
  template_id: number | null;
  template: { id: number; name: string; channel: string } | null;
  environment_id: number | null;
  status: CampaignStatus;
  segment_id: number | null;
  segment: { id: number; name: string } | null;
  sending_identity_id: number | null;
  sending_identity: { id: number; from_name: string | null; from_email: string } | null;
  recipient_count: number;
  sent_at: string | null;
  created_at: string;
  updated_at: string;
  stats: CampaignStats;
}

export interface CampaignDelivery {
  id: number;
  email: string;
  status: 'pending' | 'sent' | 'failed' | 'rejected';
  sent_at: string | null;
  opened_at: string | null;
  open_count: number;
  click_count: number;
  error_message: string | null;
  customer: { id: number; first_name: string | null; last_name: string | null } | null;
}

export interface DeliveriesResponse {
  deliveries: CampaignDelivery[];
  total: number;
  page: number;
  total_pages: number;
}

export const getCampaigns = () =>
  request.get<Campaign[]>('/campaigns').then(r => r.data);

export const getCampaign = (id: number) =>
  request.get<Campaign>(`/campaigns/${id}`).then(r => r.data);

export const createCampaign = (data: Partial<Campaign>) =>
  request.post<Campaign>('/campaigns', data).then(r => r.data);

export const updateCampaign = (id: number, data: Partial<Campaign>) =>
  request.put<Campaign>(`/campaigns/${id}`, data).then(r => r.data);

export const deleteCampaign = (id: number) =>
  request.delete(`/campaigns/${id}`).then(r => r.data);

export const sendCampaign = (id: number) =>
  request.post<{ message: string; status: string }>(`/campaigns/${id}/send_campaign`).then(r => r.data);

export const sendTestCampaign = (id: number, customerId: number) =>
  request.post<{ message: string; message_id: number }>(`/campaigns/${id}/send_test`, { customer_id: customerId }).then(r => r.data);

export const getCampaignDeliveries = (id: number, params?: { page?: number; status?: string }) =>
  request.get<DeliveriesResponse>(`/campaigns/${id}/deliveries`, { params }).then(r => r.data);

export const retryDelivery = (campaignId: number, deliveryId: number) =>
  request.post<{ message: string }>(`/campaigns/${campaignId}/retry_delivery`, { delivery_id: deliveryId }).then(r => r.data);

export const retryAllFailed = (campaignId: number) =>
  request.post<{ message: string; count: number }>(`/campaigns/${campaignId}/retry_all_failed`).then(r => r.data);


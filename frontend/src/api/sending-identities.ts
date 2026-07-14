import request from '@/utils/request';

export interface SendingIdentity {
  id: number;
  from_name: string | null;
  from_email: string;
  is_default: boolean;
  created_at: string;
  updated_at: string;
}

export interface SendingIdentityInput {
  from_name?: string;
  from_email: string;
  is_default?: boolean;
}

export const getSendingIdentities = () =>
  request.get<SendingIdentity[]>('/sending_identities').then(r => r.data);

export const createSendingIdentity = (data: SendingIdentityInput) =>
  request.post<SendingIdentity>('/sending_identities', data).then(r => r.data);

export const updateSendingIdentity = (id: number, data: Partial<SendingIdentityInput>) =>
  request.put<SendingIdentity>(`/sending_identities/${id}`, data).then(r => r.data);

export const deleteSendingIdentity = (id: number) =>
  request.delete(`/sending_identities/${id}`).then(r => r.data);

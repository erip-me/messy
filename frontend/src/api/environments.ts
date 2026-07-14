import { headerJson } from "../utils/constants";
import request from "../utils/request";

export interface Environment {
  id: number;
  name: string;
  tag: string;
  api_key: string;
  account_id: number;
  allow_email: boolean;
  allow_sms: boolean;
  allow_whatsapp: boolean;
  allow_mobile_push: boolean;
  allow_web_push: boolean;
  is_deleted: boolean;
  whatsapp_phone_id?: string;
  whatsapp_token?: string;
  notification_email_integration_id?: number | null;
  campaign_email_integration_id?: number | null;
  created_at: string;
  updated_at: string;
}

export interface CreateEnvironmentRequest {
  name: string;
}

export interface UpdateEnvironmentRequest {
  name?: string;
  tag?: string;
  allow_email?: boolean;
  allow_sms?: boolean;
  allow_whatsapp?: boolean;
  allow_mobile_push?: boolean;
  allow_web_push?: boolean;
  notification_email_integration_id?: number | null;
  campaign_email_integration_id?: number | null;
}

// Backend channel key type (what the toggle_channel action accepts)
export type BackendChannel = 'email' | 'sms' | 'whatsapp' | 'mobile_push' | 'web_push';

// Frontend display channel keys → backend field mapping
export const CHANNEL_BACKEND_KEY: Record<string, BackendChannel> = {
  email: 'email',
  sms: 'sms',
  whatsapp: 'whatsapp',
  push: 'mobile_push',
  webpush: 'web_push',
};

// Frontend display channel keys → Environment allow field mapping
export const CHANNEL_ALLOW_FIELD: Record<string, keyof Environment> = {
  email: 'allow_email',
  sms: 'allow_sms',
  whatsapp: 'allow_whatsapp',
  push: 'allow_mobile_push',
  webpush: 'allow_web_push',
};

export interface TestMessageRequest {
  channel: 'email' | 'sms' | 'whatsapp' | 'push';
  to: string;
  subject?: string;
  body: string;
}

const controller = "/environments";

export const getEnvironments = async (): Promise<Environment[]> => {
  const response = await request({
    url: controller,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};

export const getEnvironmentById = async (id: number): Promise<Environment> => {
  const response = await request({
    url: `${controller}/${id}`,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};

export const createEnvironment = async (data: CreateEnvironmentRequest): Promise<Environment> => {
  const response = await request({
    url: controller,
    method: "POST",
    data,
    headers: headerJson,
  });
  return response.data;
};

export const updateEnvironment = async (id: number, data: UpdateEnvironmentRequest): Promise<Environment> => {
  const response = await request({
    url: `${controller}/${id}`,
    method: "PUT",
    data: { environment: data },
    headers: headerJson,
  });
  return response.data;
};

export const deleteEnvironment = async (id: number): Promise<void> => {
  await request({
    url: `${controller}/${id}`,
    method: "DELETE",
    headers: headerJson,
  });
};

// POST /environments/:id/toggle_channel — backend flips the current value
export const toggleChannel = async (id: number, channel: BackendChannel): Promise<Environment> => {
  const response = await request({
    url: `${controller}/${id}/toggle_channel`,
    method: "POST",
    data: { channel },
    headers: headerJson,
  });
  return response.data;
};

export const testEnvironment = async (id: number, data: TestMessageRequest): Promise<any> => {
  const response = await request({
    url: `${controller}/${id}/test`,
    method: "POST",
    data,
    headers: headerJson,
  });
  return response.data;
};

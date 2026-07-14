import { headerJson } from "../utils/constants";
import request from "../utils/request";

export interface Integration {
  id: number;
  name: string;
  type: string;
  kind: 'email' | 'sms' | 'whatsapp' | 'mobile_push' | 'web_push' | 'social';
  vendor: string;
  environment_id: number | null;
  environment_name: string;
  config: Record<string, any>;
  active: boolean;
  created_at: string;
  updated_at: string;
}

export interface CreateIntegrationRequest {
  name: string;
  kind: 'email' | 'sms' | 'whatsapp' | 'mobile_push' | 'web_push' | 'social';
  vendor: string;
  environment_id: number;
  config: Record<string, any>;
}

export interface UpdateIntegrationRequest {
  name?: string;
  config?: Record<string, any>;
  active?: boolean;
}

// Vendor-specific config interfaces
export interface SESConfig {
  region: string;
  access_key: string;
  secret_key: string;
  from_email: string;
}

export interface SMTPConfig {
  host: string;
  port: number;
  username: string;
  password: string;
  from_email: string;
}

export interface TwilioConfig {
  account_sid: string;
  auth_token: string;
  from_number: string;
}

export interface WhatsAppConfig {
  phone_id: string;
  token: string;
}

const controller = "/integrations";

export const getIntegrations = async (): Promise<Integration[]> => {
  const response = await request({
    url: controller,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};

export const getIntegrationById = async (id: number): Promise<Integration> => {
  const response = await request({
    url: `${controller}/${id}`,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};

export const createIntegration = async (data: CreateIntegrationRequest): Promise<Integration> => {
  const response = await request({
    url: controller,
    method: "POST",
    data: { integration: data },
    headers: headerJson,
  });
  return response.data;
};

export const updateIntegration = async (id: number, data: UpdateIntegrationRequest): Promise<Integration> => {
  const response = await request({
    url: `${controller}/${id}`,
    method: "PUT",
    data: { integration: data },
    headers: headerJson,
  });
  return response.data;
};

export const deleteIntegration = async (id: number): Promise<void> => {
  await request({
    url: `${controller}/${id}`,
    method: "DELETE",
    headers: headerJson,
  });
};

export const testIntegration = async (
  id: number,
  to: string
): Promise<{ success: boolean; error?: string; status: string }> => {
  const response = await request({
    url: `${controller}/${id}/test`,
    method: "POST",
    data: { to },
    headers: headerJson,
  });
  return response.data;
};
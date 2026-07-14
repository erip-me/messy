import { headerJson } from "../utils/constants";
import request from "../utils/request";

export type TemplateChannel = "email" | "sms" | "whatsapp" | "push";

export type BodyFormat = "html" | "markdown";

export interface Template {
  id: number;
  name: string;
  trigger: string;
  channel: TemplateChannel;
  subject?: string;
  body: string;
  body_format: BodyFormat;
  preview?: string;
  folder_id?: number;
  layout_id?: number;
  environment_id: number;
  created_at: string;
  updated_at: string;
}

export interface CreateTemplateRequest {
  name: string;
  trigger: string;
  channel?: TemplateChannel;
  subject?: string;
  body: string;
  body_format?: BodyFormat;
  preview?: string;
  folder_id?: number;
  layout_id?: number;
}

export interface UpdateTemplateRequest {
  name?: string;
  trigger?: string;
  channel?: TemplateChannel;
  subject?: string;
  body?: string;
  body_format?: BodyFormat;
  preview?: string;
  folder_id?: number;
  layout_id?: number;
}

const controller = "/templates";

export const getTemplates = async (apiKey: string, folder_id?: number): Promise<Template[]> => {
  const params = new URLSearchParams();
  if (folder_id !== undefined) {
    params.append('folder_id', folder_id.toString());
  }
  
  const response = await request({
    url: `${controller}${params.toString() ? `?${params.toString()}` : ''}`,
    method: "GET",
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return response.data;
};

export const getTemplateById = async (id: number, apiKey: string): Promise<Template> => {
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

export const createTemplate = async (data: CreateTemplateRequest, apiKey: string): Promise<Template> => {
  const response = await request({
    url: controller,
    method: "POST",
    data,
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return response.data;
};

export const updateTemplate = async (id: number, data: UpdateTemplateRequest, apiKey: string): Promise<Template> => {
  const response = await request({
    url: `${controller}/${id}`,
    method: "PUT",
    data,
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return response.data;
};

export const deleteTemplate = async (id: number, apiKey: string): Promise<void> => {
  await request({
    url: `${controller}/${id}`,
    method: "DELETE",
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
};

// Uses standard JWT auth (via request interceptor) instead of apiKey
export const listTemplates = (params?: { channel?: TemplateChannel; scope?: 'account' }) =>
  request.get<Template[]>(controller, { params }).then(r => r.data);
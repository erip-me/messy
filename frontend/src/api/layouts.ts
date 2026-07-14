import { headerJson } from "../utils/constants";
import request from "../utils/request";

import type { TransformerRules } from "@/utils/markdown-transformer";

export interface Layout {
  id: number;
  name: string;
  body: string;
  transformers: TransformerRules;
  environment_id: number;
  created_at: string;
  updated_at: string;
}

export interface CreateLayoutRequest {
  name: string;
  body: string;
  transformers?: TransformerRules;
}

export interface UpdateLayoutRequest {
  name?: string;
  body?: string;
  transformers?: TransformerRules;
}

const controller = "/layouts";

export const getLayouts = async (apiKey: string): Promise<Layout[]> => {
  const response = await request({
    url: controller,
    method: "GET",
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
  return response.data;
};

export const getLayoutById = async (id: number, apiKey: string): Promise<Layout> => {
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

export const createLayout = async (data: CreateLayoutRequest, apiKey: string): Promise<Layout> => {
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

export const updateLayout = async (id: number, data: UpdateLayoutRequest, apiKey: string): Promise<Layout> => {
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

// Uses standard JWT auth (via request interceptor) instead of apiKey
export const listLayouts = () =>
  request.get<Layout[]>(controller).then(r => r.data);

export const deleteLayout = async (id: number, apiKey: string): Promise<void> => {
  await request({
    url: `${controller}/${id}`,
    method: "DELETE",
    headers: {
      ...headerJson,
      Authorization: `Bearer ${apiKey}`,
    },
  });
};

import { headerJson } from "../utils/constants";
import request from "../utils/request";

export interface DeliveryRule {
  id: number;
  name: string;
  type: 'email' | 'sms' | 'whatsapp' | 'push';
  condition: string;
  outcome: 'deliver' | 'block' | 'redirect';
  tags: string[];
  environment_id: number;
  environment_name: string;
  active: boolean;
  redirect_to?: string;
  created_at: string;
  updated_at: string;
}

export interface CreateDeliveryRuleRequest {
  name: string;
  type: 'email' | 'sms' | 'whatsapp' | 'push';
  condition: string;
  outcome: 'deliver' | 'block' | 'redirect';
  tags: string[];
  environment_id: number;
  redirect_to?: string;
}

export interface UpdateDeliveryRuleRequest {
  name?: string;
  condition?: string;
  outcome?: 'deliver' | 'block' | 'redirect';
  tags?: string[];
  active?: boolean;
  redirect_to?: string;
}

const controller = "/rules";

export const getDeliveryRules = async (environmentId?: number | null): Promise<DeliveryRule[]> => {
  const response = await request({
    url: environmentId ? `${controller}?environment_id=${environmentId}` : controller,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};

export const getDeliveryRuleById = async (id: number): Promise<DeliveryRule> => {
  const response = await request({
    url: `${controller}/${id}`,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};

export const createDeliveryRule = async (data: CreateDeliveryRuleRequest): Promise<DeliveryRule> => {
  const response = await request({
    url: controller,
    method: "POST",
    data,
    headers: headerJson,
  });
  return response.data;
};

export const updateDeliveryRule = async (id: number, data: UpdateDeliveryRuleRequest): Promise<DeliveryRule> => {
  const response = await request({
    url: `${controller}/${id}`,
    method: "PUT",
    data,
    headers: headerJson,
  });
  return response.data;
};

export const deleteDeliveryRule = async (id: number): Promise<void> => {
  await request({
    url: `${controller}/${id}`,
    method: "DELETE",
    headers: headerJson,
  });
};
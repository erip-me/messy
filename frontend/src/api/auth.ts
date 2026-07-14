import { headerJson } from "../utils/constants";
import request from "../utils/request";

export interface User {
  id: number;
  name: string;
  email: string;
  is_super_admin: boolean;
  last_login_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface LoginRequest {
  email: string;
}

export interface ValidateResponse {
  user: User;
  token: string;
}

const controller = "/magic_links";
const authorizedRoute = "/users/me";

export const loginApi = async (data: LoginRequest) => {
  const response = await request({
    url: controller,
    method: "POST",
    data,
    headers: headerJson,
  });
  return response.data;
};

export const validateApi = async (token: string): Promise<ValidateResponse> => {
  const response = await request({
    url: `${controller}/validate?token=${token}`,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};

export const authorizedApi = async (): Promise<User> => {
  const response = await request({
    url: authorizedRoute,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};

export const logoutApi = async () => {
  const response = await request({
    url: `${controller}/logout`,
    method: "DELETE",
    headers: headerJson,
  });
  return response.data;
};
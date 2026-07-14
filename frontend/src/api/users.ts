import { headerJson } from "../utils/constants";
import request from "../utils/request";

export type UserRole = "admin" | "member";

export interface User {
  id: number;
  name: string;
  email: string;
  role: UserRole;
  is_super_admin: boolean;
  account_id: number;
  last_login_at: string | null;
  created_at: string;
  updated_at: string;
  operator_profile?: {
    public_name: string;
    avatar_url: string | null;
    online: boolean;
  } | null;
}

export interface InviteUserRequest {
  name: string;
  email: string;
  role: UserRole;
}

const controller = "/users";

export const getUsers = async (): Promise<User[]> => {
  const response = await request({
    url: controller,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};

export const getUserById = async (id: number): Promise<User> => {
  const response = await request({
    url: `${controller}/${id}`,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};

export const inviteUser = async (data: InviteUserRequest): Promise<User> => {
  const response = await request({
    url: controller,
    method: "POST",
    data,
    headers: headerJson,
  });
  return response.data;
};

export const updateUserRole = async (id: number, role: UserRole): Promise<User> => {
  const response = await request({
    url: `${controller}/${id}`,
    method: "PATCH",
    data: { user: { role } },
    headers: headerJson,
  });
  return response.data;
};

export const deleteUser = async (id: number): Promise<void> => {
  await request({
    url: `${controller}/${id}`,
    method: "DELETE",
    headers: headerJson,
  });
};

export const getCurrentUser = async (): Promise<User> => {
  const response = await request({
    url: "/users/me",
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};
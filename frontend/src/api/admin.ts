import { headerJson } from "../utils/constants";
import request from "../utils/request";

export interface Account {
  id: number;
  name: string;
  plan: 'free' | 'starter' | 'pro' | 'enterprise';
  trial_ends_at?: string;
  payment_status: 'active' | 'inactive' | 'cancelled' | 'past_due';
  created_at: string;
  updated_at: string;
  trial?: boolean;
  trial_expired?: boolean;
  users: AdminUser[];
  stats?: {
    total_users: number;
    total_environments: number;
    total_templates: number;
    total_messages: number;
    messages_last_30_days: number;
  };
}

export interface AdminUser {
  id: number;
  name: string;
  email: string;
  is_super_admin: boolean;
  account_id: number;
  last_login_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface CreateAccountRequest {
  name: string;
  plan?: 'free' | 'starter' | 'pro' | 'enterprise';
  first_user?: {
    name: string;
    email: string;
  };
}

export interface UpdateAccountRequest {
  name?: string;
  plan?: 'free' | 'starter' | 'pro' | 'enterprise';
  trial_ends_at?: string;
  payment_status?: 'active' | 'inactive' | 'cancelled' | 'past_due';
}

export interface AccountsResponse {
  accounts: Account[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

export interface UsersResponse {
  users: AdminUser[];
  meta: {
    current_page: number;
    total_pages: number;
    total_count: number;
    per_page: number;
  };
}

export interface ToggleSuperAdminRequest {
  is_super_admin: boolean;
}

const accountsController = "/admin/accounts";
const usersController = "/admin/users";

// Accounts API
export const getAccounts = async (page: number = 1, per_page: number = 25): Promise<AccountsResponse> => {
  const params = new URLSearchParams({
    page: page.toString(),
    per_page: per_page.toString(),
  });

  const response = await request({
    url: `${accountsController}?${params.toString()}`,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};

export const getAccountById = async (id: number): Promise<Account> => {
  const response = await request({
    url: `${accountsController}/${id}`,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};

export const createAccount = async (data: CreateAccountRequest): Promise<Account> => {
  const response = await request({
    url: accountsController,
    method: "POST",
    data,
    headers: headerJson,
  });
  return response.data;
};

export const updateAccount = async (id: number, data: UpdateAccountRequest): Promise<Account> => {
  const response = await request({
    url: `${accountsController}/${id}`,
    method: "PUT",
    data,
    headers: headerJson,
  });
  return response.data;
};

export const deleteAccount = async (id: number): Promise<void> => {
  await request({
    url: `${accountsController}/${id}`,
    method: "DELETE",
    headers: headerJson,
  });
};

// Users API
export const getAllUsers = async (
  page: number = 1,
  per_page: number = 25,
  account_id?: number
): Promise<UsersResponse> => {
  const params = new URLSearchParams({
    page: page.toString(),
    per_page: per_page.toString(),
  });

  if (account_id) {
    params.append('account_id', account_id.toString());
  }

  const response = await request({
    url: `${usersController}?${params.toString()}`,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};

export const toggleSuperAdmin = async (id: number, data: ToggleSuperAdminRequest): Promise<AdminUser> => {
  const response = await request({
    url: `${usersController}/${id}/toggle-super-admin`,
    method: "PATCH",
    data,
    headers: headerJson,
  });
  return response.data;
};
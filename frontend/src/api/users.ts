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

// An outstanding invitation. Only the address the admin typed — someone who
// hasn't accepted isn't a member, so there is no profile to show.
export interface WorkspaceInvitation {
  id: number;
  email: string;
  role: UserRole;
  created_at: string;
}

// Inviting a brand new address creates the person outright. Inviting one that
// already has a Messy login only creates an invitation, which does nothing until
// they accept — so the response is one shape or the other.
export type InviteResult = User | { status: "invited"; email: string; role: UserRole };

export const isPendingInvite = (
  result: InviteResult,
): result is { status: "invited"; email: string; role: UserRole } =>
  (result as { status?: string }).status === "invited";

export const inviteUser = async (data: InviteUserRequest): Promise<InviteResult> => {
  const response = await request({
    url: controller,
    method: "POST",
    data,
    headers: headerJson,
  });
  return response.data;
};

export const getPendingInvitations = async (): Promise<WorkspaceInvitation[]> => {
  const response = await request({
    url: `${controller}/invitations`,
    method: "GET",
    headers: headerJson,
  });
  return response.data;
};

export const revokeInvitation = async (id: number): Promise<void> => {
  await request({
    url: `${controller}/invitations/${id}`,
    method: "DELETE",
    headers: headerJson,
  });
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
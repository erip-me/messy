import { headerJson } from "../utils/constants";
import request from "../utils/request";

export interface McpSettings {
  enabled: boolean;
  server_url: string;
}

export interface McpUser {
  id: number;
  name: string;
  email: string;
  mcp_enabled: boolean;
}

export interface McpConnection {
  id: number;
  client_name: string | null;
  user: McpUser | null;
  environment: { id: number; name: string } | null;
  scopes: string[];
  revoked: boolean;
  enabled: boolean;
  last_used_at: string | null;
  created_at: string;
}

export interface McpConnectionsResponse {
  connections: McpConnection[];
  users: McpUser[];
}

export type McpLogStatus = "ok" | "error" | "rejected";

export interface McpLog {
  id: number;
  tool_name: string | null;
  status: McpLogStatus;
  http_status: number | null;
  duration_ms: number | null;
  error_message: string | null;
  user: { id: number; name: string } | null;
  arguments: Record<string, unknown>;
  created_at: string;
}

export interface McpLogsResponse {
  logs: McpLog[];
  meta: { page: number; total: number; total_pages: number };
}

const controller = "/mcp";

export const getMcpSettings = async (): Promise<McpSettings> => {
  const response = await request({ url: `${controller}/settings`, method: "GET", headers: headerJson });
  return response.data;
};

export const updateMcpSettings = async (enabled: boolean): Promise<McpSettings> => {
  const response = await request({
    url: `${controller}/settings`,
    method: "PATCH",
    data: { enabled },
    headers: headerJson,
  });
  return response.data;
};

export const getMcpConnections = async (): Promise<McpConnectionsResponse> => {
  const response = await request({ url: `${controller}/connections`, method: "GET", headers: headerJson });
  return response.data;
};

export const revokeMcpConnection = async (id: number): Promise<void> => {
  await request({ url: `${controller}/connections/${id}`, method: "DELETE", headers: headerJson });
};

export const setMcpUserEnabled = async (userId: number, enabled: boolean): Promise<McpUser> => {
  const response = await request({
    url: `${controller}/users/${userId}`,
    method: "PATCH",
    data: { enabled },
    headers: headerJson,
  });
  return response.data;
};

export const getMcpLogs = async (page = 1): Promise<McpLogsResponse> => {
  const response = await request({
    url: `${controller}/logs`,
    method: "GET",
    params: { page },
    headers: headerJson,
  });
  return response.data;
};

// The OAuth consent decision, posted from the consent screen (auth attached
// automatically by the request interceptor).
export interface ConsentParams {
  client_id: string;
  redirect_uri: string;
  scope?: string;
  state?: string;
  code_challenge: string;
  code_challenge_method: string;
  resource?: string;
  environment_id: number;
  approved: boolean;
}

export const submitOauthConsent = async (params: ConsentParams): Promise<{ redirect_to: string }> => {
  const response = await request({ url: "/oauth/authorize", method: "POST", data: params, headers: headerJson });
  return response.data;
};

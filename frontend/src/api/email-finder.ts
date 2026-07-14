import request from "../utils/request";
import { appSettings } from "../utils/constants";
import { store } from "../store";

export interface GenerateParams {
  first_name: string;
  last_name: string;
  domain: string;
  middle_name?: string;
}

export interface VerifyResult {
  email: string;
  valid: boolean;
  reason: string;
  mx?: string;
  score?: number;
}

export const generateEmails = (params: GenerateParams) =>
  request.post<{ emails: string[] }>("/tools/email_finder/generate", params).then((r) => r.data);

export const verifyEmail = (email: string) =>
  request.post<VerifyResult>("/tools/email_finder/verify", { email }).then((r) => r.data);

/**
 * Stream-verify emails via NDJSON. Calls onResult for each email as the
 * server checks it over a single SMTP connection.
 */
export async function verifyStream(
  emails: string[],
  stopOnFirstValid: boolean,
  onResult: (result: VerifyResult) => void,
  signal?: AbortSignal
) {
  const state = store.getState();
  const token = state.auth.token || localStorage.getItem("messy_token");
  const envId = state.environment?.activeEnvironmentId?.toString();

  const headers: Record<string, string> = { "Content-Type": "application/json" };
  if (token) headers["Authorization"] = `Bearer ${token}`;
  if (envId) headers["X-Environment-Id"] = envId;

  const response = await fetch(`${appSettings.apiBaseUrl}/tools/email_finder/verify_stream`, {
    method: "POST",
    headers,
    body: JSON.stringify({ emails, stop_on_first_valid: stopOnFirstValid }),
    signal,
  });

  if (!response.ok) throw new Error(`HTTP ${response.status}`);

  const reader = response.body!.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;

    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop()!;

    for (const line of lines) {
      if (line.trim()) {
        onResult(JSON.parse(line) as VerifyResult);
      }
    }
  }

  if (buffer.trim()) {
    onResult(JSON.parse(buffer) as VerifyResult);
  }
}

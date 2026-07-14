import request from '@/utils/request';

export interface SignupRequest {
  name: string;
  email: string;
  account_name: string;
  turnstile_token?: string;
}

export interface SignupResponse {
  message: string;
  token?: string;       // dev mode only
  verify_url?: string;  // dev mode only
}

export async function signup(data: SignupRequest): Promise<SignupResponse> {
  const res = await request.post('/signup', data);
  return res.data;
}

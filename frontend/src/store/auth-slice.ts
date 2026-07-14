import { createSlice, PayloadAction } from '@reduxjs/toolkit';

interface User {
  id: string;
  name: string;
  email: string;
  role?: 'admin' | 'member';
  is_super_admin: boolean;
  account_id: string;
}

interface Account {
  id: string;
  name: string;
  plan: string;
  status: string;
  onboarding_step: number;
  onboarding_completed_at: string | null;
  trial_ends_at?: string;
  payment_status?: string;
  tracking_domain?: string;
  message_retention_days?: number;
}

interface AuthState {
  isAuthenticated: boolean;
  user: User | null;
  account: Account | null;
  token: string | null;
}

const savedToken = localStorage.getItem('messy_token');
const savedUser = localStorage.getItem('messy_user');
const savedAccount = localStorage.getItem('messy_account');

const initialState: AuthState = {
  isAuthenticated: !!savedToken,
  user: savedUser ? JSON.parse(savedUser) : null,
  account: savedAccount ? JSON.parse(savedAccount) : null,
  token: savedToken,
};

const authSlice = createSlice({
  name: 'auth',
  initialState,
  reducers: {
    setCredentials: (state, action: PayloadAction<{ user: User; account?: Account | null; token?: string }>) => {
      state.isAuthenticated = true;
      state.user = action.payload.user;
      // Only overwrite the account when one is provided. Token-refresh calls
      // (request.ts) dispatch without an account; preserving the existing one
      // avoids wrongly redirecting to onboarding after an idle session.
      if ('account' in action.payload) state.account = action.payload.account || null;
      if (action.payload.token) state.token = action.payload.token;
      if (action.payload.token) localStorage.setItem('messy_token', action.payload.token);
      if (action.payload.user) localStorage.setItem('messy_user', JSON.stringify(action.payload.user));
      if (action.payload.account) localStorage.setItem('messy_account', JSON.stringify(action.payload.account));
    },
    logout: (state) => {
      state.isAuthenticated = false;
      state.user = null;
      state.account = null;
      state.token = null;
      localStorage.removeItem('messy_token');
      localStorage.removeItem('messy_user');
      localStorage.removeItem('messy_account');
    },
    updateUser: (state, action: PayloadAction<Partial<User>>) => {
      if (state.user) {
        state.user = { ...state.user, ...action.payload };
      }
    },
  },
});

export const { setCredentials, logout, updateUser } = authSlice.actions;
export default authSlice;
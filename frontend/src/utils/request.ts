import axios from 'axios';
import { appSettings } from './constants';
import { store } from '../store';
import { logout, setCredentials } from '../store/auth-slice';

const request = axios.create({
  baseURL: appSettings.apiBaseUrl,
  withCredentials: true,
});

// Refresh the JWT when it has less than 2 hours remaining.
// Decodes the exp claim without a library (JWT payload is base64url).
const TOKEN_REFRESH_MARGIN = 2 * 60 * 60; // seconds
let refreshInFlight = false;

function tokenExpiresWithin(token: string, seconds: number): boolean {
  try {
    const payload = JSON.parse(atob(token.split(".")[1]));
    return payload.exp - Date.now() / 1000 < seconds;
  } catch {
    return false;
  }
}

function refreshTokenIfNeeded() {
  const token = store.getState().auth.token || localStorage.getItem("messy_token");
  if (!token || refreshInFlight || !tokenExpiresWithin(token, TOKEN_REFRESH_MARGIN)) return;

  refreshInFlight = true;
  request
    .get("/users/me")
    .then((res) => {
      const { user, token: newToken } = res.data;
      if (newToken && user) {
        store.dispatch(setCredentials({ user, token: newToken }));
      }
    })
    .catch(() => {})
    .finally(() => { refreshInFlight = false; });
}

// Attach JWT token and active environment to every request.
// Read token from Redux store first (always up-to-date), fall back to localStorage.
request.interceptors.request.use((config) => {
  const token = store.getState().auth.token || localStorage.getItem('messy_token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
    // Keep localStorage in sync
    localStorage.setItem('messy_token', token);
  }
  const activeEnvId =
    store.getState().environment?.activeEnvironmentId?.toString() ||
    localStorage.getItem('messy_active_env');
  if (activeEnvId) {
    config.headers['X-Environment-Id'] = activeEnvId;
  }
  return config;
});

// On every successful response, check if the token needs refreshing.
// This keeps the JWT (and therefore WebSocket connections) alive as long
// as the user is actively using the app.
request.interceptors.response.use(
  (response) => {
    refreshTokenIfNeeded();
    return response;
  },
  (error) => {
    const isAuthPage = window.location.pathname.startsWith('/login') ||
                       window.location.pathname.startsWith('/validate');
    if (error.response?.status === 401 && !isAuthPage) {
      // Dispatch logout so Redux state + localStorage are cleared atomically
      store.dispatch(logout());
      // Also wipe persist:root so redux-persist doesn't rehydrate stale session
      localStorage.removeItem('persist:root');
      window.location.href = '/login';
    }
    return Promise.reject(error);
  }
);

export default request;

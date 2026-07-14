interface AppSettings {
  [key: string]: string;
}

declare global {
  interface Window {
    __ENV__: AppSettings;
  }
}

const apiBaseUrl = window.__ENV__?.MESSY_API_URL || import.meta.env.VITE_MESSY_API_URL;
const posthogKey = window.__ENV__?.POSTHOG_KEY || import.meta.env.VITE_POSTHOG_KEY || '';
const posthogHost =
  window.__ENV__?.POSTHOG_HOST || import.meta.env.VITE_POSTHOG_HOST || 'https://eu.i.posthog.com';
const turnstileSiteKey =
  window.__ENV__?.TURNSTILE_SITE_KEY || import.meta.env.VITE_TURNSTILE_SITE_KEY || '';

export const appSettings = {
  apiBaseUrl,
  posthogKey,
  posthogHost,
  turnstileSiteKey,
};

export const headerJson = {
  "Content-Type": "application/json",
};
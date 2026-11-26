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

// Error reporting is off without a DSN (development, self-hosts without one).
const sentryDsn = window.__ENV__?.SENTRY_DSN || import.meta.env.VITE_SENTRY_DSN || '';
const sentryRelease = window.__ENV__?.SENTRY_RELEASE || undefined;
const sentryEnvironment = window.__ENV__?.SENTRY_ENVIRONMENT || 'production';

export const appSettings = {
  apiBaseUrl,
  posthogKey,
  posthogHost,
  turnstileSiteKey,
  sentryDsn,
  sentryRelease,
  sentryEnvironment,
};

export const headerJson = {
  "Content-Type": "application/json",
};
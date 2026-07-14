import posthog from 'posthog-js';
import { appSettings } from '@/utils/constants';

// Thin wrapper around posthog-js so the rest of the app never touches the SDK
// directly. Everything is a no-op when POSTHOG_KEY is not configured (local dev
// without a key, self-hosted OSS installs, etc.), so callers don't need guards.

interface IdentifiableUser {
  id: string;
  name?: string;
  email?: string;
  role?: string;
  is_super_admin?: boolean;
  account_id?: string;
}

interface IdentifiableAccount {
  id: string;
  name?: string;
  plan?: string;
  status?: string;
  payment_status?: string;
}

let started = false;

export function isAnalyticsEnabled() {
  return started;
}

export function initAnalytics() {
  if (started) return;
  if (!appSettings.posthogKey) return;

  posthog.init(appSettings.posthogKey, {
    api_host: appSettings.posthogHost,
    // We drive $pageview manually from the router (SPA — the browser only does
    // one hard navigation), so disable the automatic history-based capture.
    capture_pageview: false,
    capture_pageleave: true,
    autocapture: true,
    persistence: 'localStorage+cookie',
  });
  started = true;
}

// Tie events to the signed-in user and their tenant (account). PostHog "groups"
// model the tenant, so account-level dashboards ("active accounts", per-plan
// funnels) work regardless of which team member is using the app.
export function identify(user: IdentifiableUser, account?: IdentifiableAccount | null) {
  if (!started || !user?.id) return;

  posthog.identify(user.id, {
    email: user.email,
    name: user.name,
    role: user.role,
    is_super_admin: user.is_super_admin,
    account_id: user.account_id ?? account?.id,
  });

  if (account?.id) {
    posthog.group('account', account.id, {
      name: account.name,
      plan: account.plan,
      status: account.status,
      payment_status: account.payment_status,
    });
  }
}

export function reset() {
  if (!started) return;
  posthog.reset();
}

export function capturePageview() {
  if (!started) return;
  posthog.capture('$pageview');
}

export function capture(event: string, properties?: Record<string, unknown>) {
  if (!started) return;
  posthog.capture(event, properties);
}

export { posthog };

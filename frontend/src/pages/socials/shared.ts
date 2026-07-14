import type { SocialAlternative } from '@/api/socials';

// Socials day statuses rendered with the shared status-badge palette (see
// src/lib/status-colors.ts / index.css), so they match tags/badges app-wide.
const STATUS_STYLES: Record<string, string> = {
  pending: 'status-badge status-muted',
  ready: 'status-badge status-warning',
  posted: 'status-badge status-active',
  failed: 'status-badge status-urgent',
  skipped: 'status-badge status-muted',
};

export const statusStyle = (status: string): string => STATUS_STYLES[status] ?? 'status-badge status-muted';

export const isVideoType = (type: string | null): boolean => Boolean(type?.startsWith('video/'));

export const isVideoAlt = (alt: SocialAlternative): boolean =>
  isVideoType(alt.feed_content_type) || isVideoType(alt.reel_content_type);

export function formatHour(h: number): string {
  return `${String(h).padStart(2, '0')}:00`;
}

export function errorMessage(e: unknown, fallback: string): string {
  if (typeof e === 'object' && e && 'response' in e) {
    const resp = (e as { response?: { data?: { error?: string | string[] } } }).response;
    const err = resp?.data?.error;
    if (Array.isArray(err)) return err.join(', ');
    if (typeof err === 'string') return err;
  }
  return fallback;
}

import { describe, expect, it } from 'vitest';
import { scrub, scrubEvent } from './sentry-scrub';

describe('sentry scrub', () => {
  it('filters token path segments and query values', () => {
    const token = 'Ab3_' + 'x'.repeat(40);
    expect(scrub(`https://app.messy.sh/validate/${token}`)).toBe('https://app.messy.sh/validate/[filtered]');
    expect(scrub('https://api.messy.sh/magic_links?token=abc&email=a@b.c')).toBe(
      'https://api.messy.sh/magic_links?token=[filtered]&email=[filtered]',
    );
    expect(scrub('https://app.messy.sh/messages/42/edit')).toBe('https://app.messy.sh/messages/42/edit');
  });

  it('scrubs nested event fields', () => {
    const event = { request: { url: `/confirm-email/${'t'.repeat(32)}` }, breadcrumbs: [{ data: { to: '/x?code=9' } }] };
    expect(scrubEvent(event)).toEqual({ request: { url: '/confirm-email/[filtered]' }, breadcrumbs: [{ data: { to: '/x?code=[filtered]' } }] });
  });
});

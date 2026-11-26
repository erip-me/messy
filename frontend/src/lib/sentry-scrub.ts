// Paths carry secrets (/validate/:token, /confirm-email/:token, tracking tokens) and
// so can query strings, in the page URL, breadcrumbs and spans alike. Long token-like
// path segments and every query value leave as [filtered], wherever they sit in the event.
const SEGMENT = /\/[A-Za-z0-9_-]{20,}(?=[/?#."\\]|$)/g;
const QUERY_VALUE = /([?&][^=&#"\\\s]+=)[^&#"\\\s]*/g;

export function scrub(text: string): string {
  return text.replace(SEGMENT, '/[filtered]').replace(QUERY_VALUE, '$1[filtered]');
}

export function scrubEvent<T>(event: T): T {
  return JSON.parse(scrub(JSON.stringify(event)));
}

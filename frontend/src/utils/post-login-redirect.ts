// Where to send the user after they authenticate, when they arrived at /login
// mid-flow (e.g. the OAuth consent screen redirects here when not signed in).
//
// The path travels two ways so both login routes resume correctly:
//  - as the ?return= query param on /login (survives the same-tab dev auto-login
//    and token-paste flows), and
//  - mirrored into sessionStorage so the magic-link email path (/validate/:token,
//    which never carries the param) can pick it up in the same browser.

const KEY = "messy_post_login_redirect";

// Only allow internal absolute paths. Rejects protocol-relative ("//evil.com")
// and backslash tricks so a crafted ?return= can't bounce the user off-site.
export function sanitizeReturnPath(raw: string | null | undefined): string | null {
  if (!raw) return null;
  let decoded = raw;
  try {
    decoded = decodeURIComponent(raw);
  } catch {
    return null;
  }
  if (!decoded.startsWith("/")) return null;
  if (decoded.startsWith("//") || decoded.startsWith("/\\")) return null;
  return decoded;
}

export function storePostLoginRedirect(path: string): void {
  try {
    sessionStorage.setItem(KEY, path);
  } catch {
    /* sessionStorage unavailable — same-tab param still works */
  }
}

export function consumePostLoginRedirect(): string | null {
  try {
    const value = sessionStorage.getItem(KEY);
    if (value) sessionStorage.removeItem(KEY);
    return sanitizeReturnPath(value);
  } catch {
    return null;
  }
}

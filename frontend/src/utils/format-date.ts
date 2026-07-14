type DateInput = string | number | Date | null | undefined;

function toDate(input: DateInput): Date | null {
  if (input === null || input === undefined || input === "") return null;
  const d = input instanceof Date ? input : new Date(input);
  return isNaN(d.getTime()) ? null : d;
}

/**
 * Locale-aware short date (e.g. "6/29/2026"). Returns "" for empty/invalid input.
 * Replaces the scattered `new Date(x).toLocaleDateString()` calls.
 */
export function formatDate(input: DateInput): string {
  const d = toDate(input);
  return d ? d.toLocaleDateString() : "";
}

/**
 * Compact relative time: "now", "5m", "3h", then falls back to a short date for
 * anything older than a day. Returns "" for empty/invalid input.
 * `now` is injectable for deterministic testing.
 */
export function timeAgo(input: DateInput, now: number = Date.now()): string {
  const d = toDate(input);
  if (!d) return "";
  const diff = now - d.getTime();
  if (diff < 60000) return "now";
  if (diff < 3600000) return `${Math.floor(diff / 60000)}m`;
  if (diff < 86400000) return `${Math.floor(diff / 3600000)}h`;
  return d.toLocaleDateString();
}

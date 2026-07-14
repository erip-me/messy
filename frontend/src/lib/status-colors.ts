/** Centralized message status → CSS class mapping. Import this everywhere instead of
 *  defining STATUS_COLORS locally so every table, badge, and feed uses the same palette. */

export const STATUS_COLORS: Record<string, string> = {
  pending: "status-badge status-warning",
  sent: "status-badge status-sent",
  delivered: "status-badge status-active",
  failed: "status-badge status-urgent",
  bounced: "status-badge status-urgent",
  expired: "status-badge status-expired",
  rejected: "status-badge status-expired",
  suppressed: "status-badge status-urgent",
};

/** Returns the CSS class string for a given status, with a neutral fallback. */
export function statusClass(status: string): string {
  return STATUS_COLORS[status] || "status-badge status-muted";
}

/** Capitalises the first letter of a status string for display. */
export function statusLabel(status: string): string {
  return status.charAt(0).toUpperCase() + status.slice(1);
}

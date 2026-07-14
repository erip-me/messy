/** Centralized label & status-color maps shared across pages, so the same
 *  channel names, payment statuses, unsubscribe reasons, and helpdesk event
 *  labels are defined in exactly one place. Import from here instead of
 *  redefining these maps locally. */

/** Message channel → human label. */
export const CHANNEL_LABELS: Record<string, string> = {
  email: "Email",
  sms: "SMS",
  whatsapp: "WhatsApp",
  push: "Push",
};

/** Account payment status → badge CSS classes. */
export const PAYMENT_STATUS_COLORS: Record<string, string> = {
  active: "bg-green-100 text-green-800",
  inactive: "bg-gray-100 text-gray-800",
  cancelled: "bg-red-100 text-red-800",
  past_due: "bg-yellow-100 text-yellow-800",
};

/** Unsubscribe reason code → human label. */
export const UNSUB_REASON_LABELS: Record<string, string> = {
  bounce: "Bounced",
  complaint: "Spam complaint",
  invalid_email: "Invalid email",
  campaign_unsubscribe: "Unsubscribed via campaign",
};

/** Helpdesk lifecycle event → human label. */
export const HELPDESK_EVENT_LABELS: Record<string, string> = {
  ticket_created: "Ticket Created (auto-reply acknowledgement)",
  ticket_assigned: "Ticket Assigned to Operator",
  ticket_reply_from_operator: "Operator Reply",
  ticket_closed: "Ticket Closed / Resolved",
  ticket_reopened: "Ticket Reopened",
};

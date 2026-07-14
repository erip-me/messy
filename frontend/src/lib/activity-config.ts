/** Centralized customer-activity → label/icon/colour mapping. Import this everywhere
 *  (customer timeline, live feed) so every view labels activity types identically.
 *  Only `identify` represents a real login / "came online"; campaign events must never
 *  be rendered as online. */

import { Mail, UserCheck, Megaphone, Eye, MousePointer, MailX, Layers } from "lucide-react";

export interface ActivityConfig {
  /** Human label for the event, e.g. "Opened email". */
  label: string;
  /** Short uppercase tag for compact table rows, e.g. "OPENED". */
  badge: string;
  /** Status-pill text, e.g. "opened". */
  status: string;
  /** Existing status-badge variant class to reuse for the status pill. */
  statusClass: string;
  Icon: typeof Mail;
  /** Row background tint. */
  bg: string;
  /** Icon / badge text colour. */
  iconColor: string;
  /** Left-accent border colour. */
  border: string;
}

export const ACTIVITY_CONFIG: Record<string, ActivityConfig> = {
  identify:              { label: "Logged in",     badge: "IDENTIFY", status: "logged in",    statusClass: "status-active", Icon: UserCheck,    bg: "bg-yellow-50/50", iconColor: "text-yellow-700", border: "border-l-yellow-400" },
  campaign_sent:         { label: "Campaign sent", badge: "SENT",     status: "sent",         statusClass: "status-sent",   Icon: Megaphone,    bg: "bg-blue-50/50",   iconColor: "text-blue-700",   border: "border-l-blue-400" },
  campaign_opened:       { label: "Opened email",  badge: "OPENED",   status: "opened",       statusClass: "status-active", Icon: Eye,          bg: "bg-green-50/50",  iconColor: "text-green-700",  border: "border-l-green-400" },
  campaign_clicked:      { label: "Clicked link",  badge: "CLICKED",  status: "clicked",      statusClass: "status-active", Icon: MousePointer, bg: "bg-purple-50/50", iconColor: "text-purple-700", border: "border-l-purple-400" },
  campaign_unsubscribed: { label: "Unsubscribed",  badge: "UNSUB",    status: "unsubscribed", statusClass: "status-urgent", Icon: MailX,        bg: "bg-red-50/50",    iconColor: "text-red-700",    border: "border-l-red-400" },
  segment_entered:       { label: "Entered segment", badge: "ENTERED", status: "entered",     statusClass: "status-active", Icon: Layers,       bg: "bg-indigo-50/50", iconColor: "text-indigo-700", border: "border-l-indigo-400" },
  segment_exited:        { label: "Exited segment",  badge: "EXITED",  status: "exited",      statusClass: "status-inactive", Icon: Layers,     bg: "bg-slate-50/50",  iconColor: "text-slate-700",  border: "border-l-slate-400" },
};

/** Returns the config for an activity type, falling back to the `identify` style. */
export function activityConfig(activityType: string): ActivityConfig {
  return ACTIVITY_CONFIG[activityType] || ACTIVITY_CONFIG.identify;
}

/** Collapses repeated items to the most recent occurrence per key. Assumes `items`
 *  is already ordered newest-first, so the first occurrence of each key is kept.
 *  Items whose key is unique (e.g. messages) are always preserved. */
export function dedupeLatest<T>(items: T[], keyFn: (item: T) => string): T[] {
  const seen = new Set<string>();
  const result: T[] = [];
  for (const item of items) {
    const key = keyFn(item);
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(item);
  }
  return result;
}

import React from "react";

/**
 * Parse a recipient string like:
 *   "DisplayName" <email@example.com>; "Other" <other@example.com>
 * into an array of { displayName, email } objects.
 */

export interface ParsedRecipient {
  displayName: string | null;
  email: string;
}

export function parseRecipients(raw: string): ParsedRecipient[] {
  if (!raw || !raw.trim()) return [];

  // Split on semicolons or commas (common delimiters)
  const parts = raw.split(/[;,]/).map((s) => s.trim()).filter(Boolean);

  return parts.map((part) => {
    // Match "DisplayName" <email> or DisplayName <email>
    const match = part.match(/^"?([^"<]+?)"?\s*<([^>]+)>$/);
    if (match) {
      return { displayName: match[1].trim(), email: match[2].trim() };
    }
    // Match <email> only
    const emailOnly = part.match(/^<([^>]+)>$/);
    if (emailOnly) {
      return { displayName: null, email: emailOnly[1].trim() };
    }
    // Plain email or text
    return { displayName: null, email: part.trim() };
  });
}

/**
 * Renders a formatted recipient list with "and X others" styled lighter.
 */
export function FormattedRecipients({
  raw,
  maxVisible = 2,
}: {
  raw: string;
  maxVisible?: number;
}) {
  const recipients = parseRecipients(raw);
  if (recipients.length === 0) return <>{raw || ""}</>;

  const labels = recipients.map((r) => r.displayName || r.email);

  if (labels.length <= maxVisible) {
    return <>{labels.join(", ")}</>;
  }

  const visible = labels.slice(0, maxVisible).join(", ");
  const remaining = labels.length - maxVisible;
  return (
    <>
      {visible}{" "}
      <span className="text-muted-foreground font-normal">
        and {remaining} others
      </span>
    </>
  );
}

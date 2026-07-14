/**
 * Derive avatar initials from a contact's name parts, falling back to the
 * first letter of their email, then "?". Mirrors the inline logic previously
 * duplicated across the customer pages.
 */
export function getInitials(
  firstName?: string | null,
  lastName?: string | null,
  email?: string | null
): string {
  return (
    [firstName?.[0], lastName?.[0]].filter(Boolean).join("").toUpperCase() ||
    email?.[0]?.toUpperCase() ||
    "?"
  );
}

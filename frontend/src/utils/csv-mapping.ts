/** Pure helpers for the customer CSV import wizard's column → field mapping. */

/**
 * Guess a sensible default field mapping for uploaded CSV headers. Recognises
 * common email / first name / last name spellings (case/space/underscore
 * insensitive); everything else defaults to "skip".
 */
export function deriveDefaultMapping(headers: string[]): Record<string, string> {
  const mapping: Record<string, string> = {};
  headers.forEach((h) => {
    const lc = h.toLowerCase();
    if (lc === "email") mapping[h] = "email";
    else if (lc === "first_name" || lc === "firstname" || lc === "first name")
      mapping[h] = "first_name";
    else if (lc === "last_name" || lc === "lastname" || lc === "last name")
      mapping[h] = "last_name";
    else mapping[h] = "skip";
  });
  return mapping;
}

/**
 * Resolve the user-facing field mapping into the API payload mapping: columns
 * marked "custom" are emitted as `custom:<trimmed name>` (and dropped entirely
 * if no name was supplied); all other columns pass through unchanged.
 */
export function toEffectiveMapping(
  fieldMapping: Record<string, string>,
  customNames: Record<string, string>
): Record<string, string> {
  const mapping: Record<string, string> = {};
  Object.entries(fieldMapping).forEach(([col, field]) => {
    if (field === "custom") {
      const name = customNames[col]?.trim();
      if (name) mapping[col] = `custom:${name}`;
    } else {
      mapping[col] = field;
    }
  });
  return mapping;
}

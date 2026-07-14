export function ticketNum(raw: string | null) {
  if (!raw) return "";
  return raw.replace(/^[A-Z]+-/, "").replace(/^#/, "");
}

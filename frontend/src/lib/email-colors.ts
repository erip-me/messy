/** Literal hex colors used when generating email HTML.
 *
 * Email clients can't resolve CSS custom properties or Tailwind classes, so
 * these intentionally stay literal hex values. They live here (rather than
 * scattered across markdown-transformer + layout templates) so the email
 * palette is defined once. */
export const EMAIL_COLORS = {
  /** Link / CTA blue. */
  link: "#3B86E4",
  /** Hairline borders (blockquote rule, horizontal rule). */
  border: "#e0e0e0",
  /** Muted body / quoted text. */
  mutedText: "#666",
  /** Outer email background. */
  bodyBg: "#f4f4f5",
  /** Content card background. */
  contentBg: "#ffffff",
  /** Footer text. */
  footerText: "#71717a",
  /** Placeholder text shown in previews. */
  placeholderText: "#a1a1aa",
} as const;

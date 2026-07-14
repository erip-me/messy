interface RequiredAsteriskProps {
  /** When true, the asterisk turns red (field is missing after a failed submission) */
  error?: boolean;
}

export function RequiredAsterisk({ error }: RequiredAsteriskProps) {
  return (
    <span
      className={error ? 'text-destructive' : 'text-foreground'}
      aria-hidden="true"
    >
      *
    </span>
  );
}

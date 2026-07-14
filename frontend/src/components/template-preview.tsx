// Shared building blocks for the template/layout/campaign previews. The pipeline
// that produces the HTML (Liquid substitution → markdown → layout wrap) differs
// per caller and stays at the call site; what's identical — and security-critical
// — is the sandboxed, auto-resizing iframe, so only that lives here.

interface PreviewFrameProps {
  /** Fully-rendered HTML to display. */
  html: string;
  /** Minimum rendered height in px (applied via Math.max in onLoad). 0 = none. */
  minHeight?: number;
  /** Extra classes; pass a `min-h-[Npx]` here if you prefer a CSS floor. */
  className?: string;
  title?: string;
}

// `sandbox="allow-same-origin"` (and NOT allow-scripts) is required: template
// bodies are author-supplied, and without it a <script> in one would run in the
// operator's session and could read the auth token.
export function PreviewFrame({
  html,
  minHeight = 0,
  className = "w-full border-0",
  title = "Preview",
}: PreviewFrameProps) {
  return (
    <iframe
      srcDoc={html}
      title={title}
      sandbox="allow-same-origin"
      className={className}
      onLoad={(e) => {
        const iframe = e.target as HTMLIFrameElement;
        if (iframe.contentDocument) {
          const h = iframe.contentDocument.documentElement.scrollHeight;
          iframe.style.height = (minHeight ? Math.max(minHeight, h) : h) + "px";
        }
      }}
    />
  );
}

// Plaintext channels (SMS/push) show the raw body in a wrapped <pre> instead of
// an iframe.
export function PlaintextPreview({ text }: { text: string }) {
  return (
    <div className="p-4 prose prose-sm max-w-none">
      <pre className="whitespace-pre-wrap text-sm font-sans">{text}</pre>
    </div>
  );
}

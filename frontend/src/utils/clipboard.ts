/**
 * Copy text to clipboard.
 * Falls back to execCommand for non-HTTPS / non-localhost origins
 * where navigator.clipboard is unavailable.
 */
export function copyToClipboard(text: string): Promise<void> {
  if (navigator.clipboard?.writeText) {
    return navigator.clipboard.writeText(text);
  }

  return new Promise((resolve, reject) => {
    const el = document.createElement('textarea');
    el.value = text;
    el.style.cssText = 'position:fixed;top:-9999px;left:-9999px;opacity:0';
    document.body.appendChild(el);
    el.select();
    const ok = document.execCommand('copy');
    document.body.removeChild(el);
    ok ? resolve() : reject(new Error('execCommand copy failed'));
  });
}

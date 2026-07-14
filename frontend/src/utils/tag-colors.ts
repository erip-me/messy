// Deterministic name -> color mapping over the existing design-token palette.
// Colors reference the status-* CSS variables defined in src/index.css so tags
// reuse the catalog palette (no new colors are introduced). Each entry is a
// background/text pair with built-in contrast.
const TAG_PALETTE: { backgroundColor: string; color: string }[] = [
  { backgroundColor: "hsl(var(--status-green))", color: "hsl(var(--status-green-text))" },
  { backgroundColor: "hsl(var(--status-amber))", color: "hsl(var(--status-amber-text))" },
  { backgroundColor: "hsl(var(--status-coral))", color: "hsl(var(--status-coral-text))" },
  { backgroundColor: "hsl(var(--status-orange))", color: "hsl(var(--status-orange-text))" },
  { backgroundColor: "hsl(var(--status-blue))", color: "hsl(var(--status-blue-text))" },
  { backgroundColor: "hsl(var(--accent))", color: "hsl(var(--accent-foreground))" },
];

// Simple deterministic string hash (djb2-style) so the same name always maps
// to the same palette bucket and different names spread across the palette.
function hashName(name: string): number {
  let hash = 5381;
  for (let i = 0; i < name.length; i++) {
    hash = (hash * 33) ^ name.charCodeAt(i);
  }
  return Math.abs(hash);
}

function paletteEntry(name: string): { backgroundColor: string; color: string } {
  return TAG_PALETTE[hashName(name) % TAG_PALETTE.length];
}

export function getTagColor(name: string): string {
  return paletteEntry(name).color;
}

export function tagStyle(name: string): { backgroundColor: string; color: string } {
  return paletteEntry(name);
}

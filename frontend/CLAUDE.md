# Frontend Styling & Conventions

This document describes how the Messy frontend is actually built. The stack is
**React + TypeScript + Vite**, styled with **Tailwind CSS** and **shadcn/ui**
(Radix primitives + class-variance-authority). There is **no SCSS/BEM** in this
codebase — ignore any older guidance that references `.scss`, `rem()`, or a blue
`#3B86E4` brand color.

## Design System

### Source of truth for tokens
- **CSS variables** live in `src/index.css` under `:root` (and `.dark`). They are
  HSL triplets, e.g. `--primary: 217 91% 60%` (the vibrant-blue brand color, ≈ `#3B82F6`).
- **Tailwind** consumes those vars in `tailwind.config.js` via
  `hsl(var(--token))`, exposing classes like `bg-primary`, `text-primary`,
  `border-primary`, `bg-muted`, `text-muted-foreground`, `bg-accent`, etc.

### Brand / primary color
- Primary is **vibrant blue** `hsl(217 91% 60%)` (`#3B82F6`). Use `bg-primary` /
  `text-primary` / `border-primary` / `ring-ring`. **Never** hardcode the hex (or the
  old teal `#2A5F5E`) in class names or inline styles. `--accent` is a soft blue tint
  (active pills / selected rows / menu hover); `--ring` matches primary.

### Status colors
Defined as paired bg/text CSS vars in `index.css` and surfaced through the
`.status-badge` + `.status-*` component classes (`status-active`,
`status-warning`, `status-urgent`, `status-sent`, `status-expired`,
`status-muted`). For message statuses, import the central map:
`src/lib/status-colors.ts` (`statusClass()`, `statusLabel()`).

### Chart colors
Charts (recharts) and any data-categorical fills use the chart token palette:
`--chart-teal`, `--chart-sage`, `--chart-terracotta`, `--chart-sand`,
`--chart-slate`, `--chart-plum`. Reference them as `hsl(var(--chart-*))` (for
recharts `stroke`/`fill` props) or the `chart-*` Tailwind colors. Do **not**
inline raw `hsl(...)` literals — use the token.

### Tag colors
Tag swatches/badges derive a deterministic color from the tag name via
`src/utils/tag-colors.ts` (`getTagColor`, `tagStyle`), which hashes the name onto
the shared `--status-*` token palette. This is a sanctioned data-driven inline
style — keep using these helpers rather than re-deriving colors.

### Typography
- `Inter` is the default sans (`font-sans`, applied to `body`).
- `Playfair Display` is the serif for headings (`font-serif`, the
  `.serif-heading` and `.page-heading` component classes).
- Use Tailwind text utilities (`text-sm`, `text-2xl`, `font-semibold`, …); there
  is no `rem()` helper.

## Components

### Catalog first
Reusable primitives live in `src/components/ui/` (shadcn): `Button`, `Input`,
`Label`, `Badge`, `Card`, `Dialog`, `Select`, `Switch`, `Table`, `Tabs`,
`DropdownMenu`, `Skeleton`, `Tooltip`, etc. **Always reach for these before
writing a raw element.**

- Buttons: `<Button variant="default|outline|ghost|secondary|destructive|link"
  size="default|sm|lg|icon">`. Don't hand-roll `<button>` with bespoke classes
  when a variant fits.
- Removable chips/pills: `<Badge variant="secondary">` + an inline icon button
  with an `<X />` (see `rules/edit.tsx` TagInput, `onboarding.tsx` invite list).
- Stat / KPI cards: reuse `src/components/metric-tile.tsx` (`<MetricTile>`).

### Shared utilities & maps
Centralized, import-don't-redefine:
- `src/utils/format-date.ts` — `formatDate()`, `timeAgo()`.
- `src/lib/labels.ts` — `CHANNEL_LABELS`, `PAYMENT_STATUS_COLORS`,
  `UNSUB_REASON_LABELS`, `HELPDESK_EVENT_LABELS`.
- `src/lib/status-colors.ts` — message status → CSS class.
- `src/lib/email-colors.ts` — literal hex colors for generated **email** HTML
  (email clients can't use CSS vars, so these stay hex, but live in one place).

## Styling Rules

1. **No new colors / CSS / inline styles.** Compose from existing Tailwind tokens
   and the shadcn catalog. The only sanctioned inline `style={{}}` cases are
   genuinely dynamic/computed values (e.g. `transform: scale(zoom)`,
   depth-based padding, computed opacity, data-driven tag/widget colors).
2. **Static values belong in className.** Convert fixed dimensions/spacing to
   Tailwind utilities (e.g. `min-h-[500px]`, `w-full`, `border-0`) rather than
   inline styles.
3. **Reuse over re-create.** Match existing patterns; prefer extracting a shared
   component/util over copy-paste.
4. **Email HTML is the exception** — it uses literal hex (via
   `src/lib/email-colors.ts`) because mail clients don't support CSS variables.

## Path Aliases
`@/` maps to `src/` (configured in `vite.config.ts` and `tsconfig.app.json`).
Prefer `@/components/...`, `@/lib/...`, `@/utils/...` imports.

## Code Quality

- ESLint: `.eslintrc.cjs` / `eslint.config`. Run `npm run lint`.
- TypeScript: avoid `any`, prefix intentionally-unused vars with `_`.
- Quotes/semicolons/indentation follow the existing files in the directory you're
  editing — match the surrounding style.

## Build & Test

- `npm run dev` — Vite dev server.
- `npm run build` — production build (`vite build`).
- `npm run build:check` — `tsc -b && vite build` (typecheck + build).
- `npm run test:unit` — Vitest unit tests (colocated `src/**/*.test.ts`).
- `npm test` — Playwright e2e (`tests/*.spec.ts`).

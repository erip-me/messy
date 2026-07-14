import { defineConfig } from "vitest/config";
import path from "path";

// Unit-test config (Vitest). Kept separate from the Playwright e2e suite in
// `tests/` — Vitest only runs the colocated `src/**/*.test.ts` files.
export default defineConfig({
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  test: {
    include: ["src/**/*.test.ts"],
    environment: "node",
  },
});

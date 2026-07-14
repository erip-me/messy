import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import svgr from "vite-plugin-svgr";
import fs from "fs";
import path from "path";
import type { ServerOptions } from "vite";

// Build server config
const serverConfig: ServerOptions = {};

// Allow additional hosts from environment variable
// Extract domain from base URL (remove protocol)
let allowedHosts: string[] | undefined;
if (process.env.CORS_DOMAIN) {
  try {
    const url = new URL(process.env.CORS_DOMAIN);
    allowedHosts = [url.hostname];
    serverConfig.allowedHosts = allowedHosts;
  } catch (e) {
    console.warn('Invalid CORS_DOMAIN:', process.env.CORS_DOMAIN);
  }
}

// https://vitejs.dev/config/
export default defineConfig({
  server: {
    ...serverConfig,
    port: 5176,
    host: '0.0.0.0',
    allowedHosts: true,
    hmr: {
      host: (() => {
        try {
          // Read CORS_DOMAIN from .env file directly
          const envContent = fs.readFileSync(path.resolve(__dirname, '.env'), 'utf-8');
          const match = envContent.match(/CORS_DOMAIN=https?:\/\/([^:\s/]+)/);
          return match ? match[1] : 'localhost';
        } catch { return 'localhost'; }
      })(),
    },
  },
  preview: {
    allowedHosts: allowedHosts,
  },
  plugins: [react(), svgr()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  css: {
    preprocessorOptions: {
      scss: {
        silenceDeprecations: ['mixed-decls'],
      },
    },
  },
});

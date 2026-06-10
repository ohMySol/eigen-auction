import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { fileURLToPath, URL } from "node:url";

// __dirname equivalent in ESM: the directory containing this config file (src/frontend/).
const frontendDir = fileURLToPath(new URL(".", import.meta.url));
const repoRoot = fileURLToPath(new URL("../..", import.meta.url));

// The deploy script writes the address artifact to repo-root/deployments/. We expose it so the
// chain layer can bundle the matching <chainId>.json at build time.
export default defineConfig({
  root: frontendDir,
  plugins: [react()],
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
  resolve: {
    alias: {
      "@deployments": `${repoRoot}/deployments`,
    },
  },
  server: {
    fs: {
      // Allow Vite dev mode to read files outside its root (for the deployments/ alias).
      allow: [repoRoot],
    },
  },
});

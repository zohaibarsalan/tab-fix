import { defineConfig } from "vite";

export default defineConfig({
  root: ".",
  build: {
    outDir: "dist/renderer",
    emptyOutDir: false,
    sourcemap: true,
    rollupOptions: {
      input: "index.html"
    }
  },
  server: {
    host: "127.0.0.1",
    port: 5173,
    strictPort: false
  }
});


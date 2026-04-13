import { defineConfig } from "vite";
import path from "node:path";

export default defineConfig({
  root: path.resolve(__dirname),
  build: {
    outDir: "../../dist/desktop/renderer",
    emptyOutDir: false,
    sourcemap: true,
    rollupOptions: {
      input: {
        app: path.resolve(__dirname, "index.html"),
        overlay: path.resolve(__dirname, "overlay.html")
      }
    }
  },
  server: {
    host: "127.0.0.1",
    port: 5173,
    strictPort: false
  }
});


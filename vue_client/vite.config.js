import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import path from 'path';

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src')
    }
  },
  server: {
    port: 5188,
    proxy: {
      // xfwd: true forwards the browser-facing host (localhost:5188) as
      // X-Forwarded-Host. Without this, WebAuthn origin verification fails
      // in dev because the credential is bound to :5188 but the proxy
      // rewrites Host to :8010.
      '/api': {
        target: 'http://localhost:8010',
        changeOrigin: true,
        xfwd: true
      },
      '/uploads': {
        target: 'http://localhost:8010',
        changeOrigin: true,
        xfwd: true
      },
      '/preview': {
        target: 'http://localhost:8010',
        changeOrigin: true,
        xfwd: true
      }
    }
  }
});

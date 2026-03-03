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
      '/api': {
        target: 'http://localhost:8010',
        changeOrigin: true
      },
      '/uploads': {
        target: 'http://localhost:8010',
        changeOrigin: true
      },
      '/preview': {
        target: 'http://localhost:8010',
        changeOrigin: true
      }
    }
  }
});

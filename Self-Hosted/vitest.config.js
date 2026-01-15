import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['server/**/*.test.js', 'tests/**/*.test.js'],
    testTimeout: 30000,
  },
});

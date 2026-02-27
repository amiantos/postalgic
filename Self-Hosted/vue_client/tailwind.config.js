/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#eff6ff',
          100: '#dbeafe',
          200: '#bfdbfe',
          300: '#93c5fd',
          400: '#60a5fa',
          500: '#3b82f6',
          600: '#2563eb',
          700: '#1d4ed8',
          800: '#1e40af',
          900: '#1e3a8a',
        },
        // Site template matching colors (default blog theme)
        'site-bg': '#efefef',
        'site-text': '#2d3748',
        'site-accent': '#FFA100',
        'site-light': '#dedede',
        'site-medium': '#a0aec0',
        'site-dark': '#4a5568',
      },
    },
  },
  plugins: [
    require('@tailwindcss/typography'),
  ],
}

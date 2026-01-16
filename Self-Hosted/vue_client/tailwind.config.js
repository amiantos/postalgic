/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'media',
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Keep primary for compatibility
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
        // Retro 1999-2000 color palette
        retro: {
          // Bold blues
          'blue': '#0066CC',
          'blue-light': '#3399FF',
          'blue-dark': '#003366',
          'blue-link': '#0000FF',
          'blue-visited': '#660099',
          // Orange accent (matches default blog template)
          'orange': '#FFA100',
          'orange-dark': '#CC8000',
          // Green
          'green': '#009900',
          'green-lime': '#99CC00',
          // Structural grays
          'gray-lightest': '#EEEEEE',
          'gray-light': '#CCCCCC',
          'gray-medium': '#999999',
          'gray-dark': '#666666',
          'gray-darker': '#333333',
          // Backgrounds
          'cream': '#F5F5F0',
          'white': '#FFFFFF',
          // Dark mode palette
          'dark-bg': '#1A1A2E',
          'dark-surface': '#252540',
          'dark-border': '#3D3D60',
          'dark-highlight': '#4D4D70',
        }
      },
      fontFamily: {
        'retro-sans': ['Verdana', 'Geneva', 'Tahoma', 'sans-serif'],
        'retro-serif': ['Georgia', 'Times New Roman', 'Times', 'serif'],
        'retro-mono': ['Monaco', 'Courier New', 'monospace'],
      },
      fontSize: {
        'retro-xs': ['10px', { lineHeight: '14px' }],
        'retro-sm': ['11px', { lineHeight: '16px' }],
        'retro-base': ['12px', { lineHeight: '18px' }],
        'retro-lg': ['14px', { lineHeight: '20px' }],
        'retro-xl': ['16px', { lineHeight: '22px' }],
        'retro-2xl': ['18px', { lineHeight: '24px' }],
        'retro-title': ['24px', { lineHeight: '28px' }],
      },
      borderRadius: {
        'retro-none': '0px',
        'retro-sm': '2px',
        'retro-md': '3px',
      },
    },
  },
  plugins: [
    require('@tailwindcss/typography'),
  ],
}

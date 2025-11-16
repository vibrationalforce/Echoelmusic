/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          50: '#e0f7ff',
          100: '#b3ebff',
          200: '#80deff',
          300: '#4dd1ff',
          400: '#26c7ff',
          500: '#00bdff', // Cyan
          600: '#00a8e6',
          700: '#008fcc',
          800: '#0076b3',
          900: '#005a8c',
        },
        secondary: {
          500: '#FF00FF', // Magenta
        },
        accent: {
          500: '#651FFF', // Purple
        },
        dark: {
          bg: '#1A1A2E',
          surface: '#16213E',
        }
      }
    },
  },
  plugins: [],
}

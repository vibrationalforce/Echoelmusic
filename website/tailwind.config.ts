import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: '#00E5FF',
          dark: '#00B8D4',
        },
        secondary: {
          DEFAULT: '#FF00FF',
          dark: '#C51162',
        },
        accent: '#651FFF',
        dark: {
          DEFAULT: '#1A1A2E',
          lighter: '#16213E',
        },
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['IBM Plex Mono', 'monospace'],
        display: ['VT323', 'monospace'],
      },
      animation: {
        'gradient': 'gradient 15s ease infinite',
        'pulse-slow': 'pulse 4s cubic-bezier(0.4, 0, 0.6, 1) infinite',
        'glow': 'glow 2s ease-in-out infinite alternate',
      },
      keyframes: {
        gradient: {
          '0%, 100%': {
            'background-size': '200% 200%',
            'background-position': 'left center'
          },
          '50%': {
            'background-size': '200% 200%',
            'background-position': 'right center'
          },
        },
        glow: {
          'from': {
            'box-shadow': '0 0 20px #00E5FF, 0 0 30px #00E5FF, 0 0 40px #00E5FF',
          },
          'to': {
            'box-shadow': '0 0 30px #FF00FF, 0 0 40px #FF00FF, 0 0 50px #FF00FF',
          },
        },
      },
    },
  },
  plugins: [],
};
export default config;

/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: {
          50: '#eff7f3',
          100: '#d8ece1',
          200: '#b3d9c6',
          300: '#84bfa4',
          400: '#529f80',
          500: '#2f8264',
          600: '#1f6850',
          700: '#195340',
          800: '#163f33',
          900: '#0b2e25',
          950: '#061a15'
        },
        gold: {
          50: '#fbf7ea',
          100: '#f5ecc8',
          200: '#ebd88f',
          300: '#dfbf55',
          400: '#d4aa32',
          500: '#c9a227',
          600: '#a37d1e',
          700: '#7d5c1a',
          800: '#5d441a',
          900: '#3f2f16'
        },
        sand: {
          50: '#faf8f4',
          100: '#f2ede3',
          200: '#e5dccb',
          300: '#d3c4a9',
          400: '#bda886',
          500: '#a88f68'
        }
      },
      fontFamily: {
        sans: ['Inter', 'Noto Sans', 'system-ui', '-apple-system', 'Segoe UI', 'sans-serif']
      },
      boxShadow: {
        card: '0 1px 2px rgba(6,26,21,.06), 0 12px 32px -12px rgba(6,26,21,.18)'
      }
    }
  },
  plugins: []
};

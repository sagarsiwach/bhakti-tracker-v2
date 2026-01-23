/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./App.{js,jsx,ts,tsx}", "./src/**/*.{js,jsx,ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        earth: {
          50: '#faf6f1',
          100: '#f0e6d8',
          200: '#e4d4be',
          300: '#d4bc9a',
          400: '#c4a47a',
          500: '#b08d5e',
          600: '#9a7650',
          700: '#7d5f43',
          800: '#664d39',
          900: '#544030',
          950: '#2d2118'
        },
        saffron: {
          50: '#fff8ed',
          100: '#ffefd4',
          200: '#ffdba8',
          300: '#ffc170',
          400: '#ff9d37',
          500: '#ff8210',
          600: '#f06806',
          700: '#c74e07',
          800: '#9e3d0e',
          900: '#7f340f',
          950: '#451805'
        }
      }
    }
  },
  plugins: [],
}

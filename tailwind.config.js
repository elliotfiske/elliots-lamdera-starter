/** @type {import('tailwindcss').Config} */
module.exports = {
  // Scan all Elm source for class names. After adding new classes, re-run the
  // build (`npm run build:css`) or keep `npm run watch:css` going.
  content: ['./src/**/*.elm'],
  theme: {
    extend: {},
  },
  plugins: [],
}

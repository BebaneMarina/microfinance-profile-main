module.exports = {
  content: [
    "./src/**/*.{html,ts}",
    "./projects/**/*.{html,ts}"
  ],
  corePlugins: {
    preflight: false, // Important pour Angular
  },
  theme: {
    extend: {},
  },
  plugins: [],
}
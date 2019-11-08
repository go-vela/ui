const autoprefixer = require("autoprefixer");
const purgecss = require("@fullhuman/postcss-purgecss");

const development = {
  plugins: [autoprefixer]
};

const production = {
  plugins: [
    purgecss({
      content: ["./src/**/*.elm", "./src/static/index.js"],
      whitelist: ["html", "body", "svg"]
    }),
    autoprefixer
  ]
};

if (process.env.NODE_ENV === "production") {
  module.exports = production;
} else {
  module.exports = development;
}

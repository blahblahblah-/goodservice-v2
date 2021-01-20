const { environment } = require('@rails/webpacker')

environment.loaders.get('sass').use.splice(-1, 0, {
  loader: 'resolve-url-loader',
  options: {
    attempts: 1
  }
});

module.exports = environment

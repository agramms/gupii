require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Gupii
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.

    # Brazilian timezone for PIX integration
    config.time_zone = "America/Sao_Paulo"

    # Default locale for Brazilian Portuguese
    config.i18n.default_locale = :"pt-BR"

    # Available locales for PIX system
    config.i18n.available_locales = [ :"pt-BR", :en ]

    # Fallback to English if translation missing
    config.i18n.fallbacks = [ :"pt-BR", :en ]

    # Domain-based development environment - no subpath configuration needed
    # Applications now run on dedicated domains (gupii.local, grafana.gupii.local, etc.)

    # Load locale files from subdirectories
    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]

    # Track application start time for metrics
    config.start_time = Time.current

    # Add simple Prometheus metrics middleware
    require_relative "../lib/simple_prometheus_middleware" unless Rails.env.test?
    config.middleware.use SimplePrometheusMiddleware unless Rails.env.test?

    # config.eager_load_paths << Rails.root.join("extras")
  end
end

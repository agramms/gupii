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
    config.i18n.available_locales = [:"pt-BR", :en]
    
    # Fallback to English if translation missing
    config.i18n.fallbacks = [:"pt-BR", :en]
    
    # Configure relative URL root for subpath deployment
    # This allows Rails to work correctly when deployed under /app/ path via nginx
    if ENV['RAILS_RELATIVE_URL_ROOT']
      config.relative_url_root = ENV['RAILS_RELATIVE_URL_ROOT']
      routes.default_url_options[:script_name] = ENV['RAILS_RELATIVE_URL_ROOT']
    end
    
    # Load locale files from subdirectories
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]
    
    # config.eager_load_paths << Rails.root.join("extras")
  end
end

# AppConfig is loaded in config/application.rb for early availability

# Ensure AppConfig is reloaded in development when files change
Rails.application.config.to_prepare do
  load Rails.root.join('app/lib/app_config.rb') if Rails.env.development?
end
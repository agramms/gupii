# Subpath Configuration Initializer
#
# This initializer handles Rails application subpath configuration with
# environment-specific safety checks to prevent production misconfigurations.

Rails.application.configure do
  # Ensure subpath configuration only applies in development
  if Rails.env.production? && config.relative_url_root.present?
    Rails.logger.fatal "CRITICAL: relative_url_root is configured in production environment!"
    Rails.logger.fatal "Production applications should not use subpath configuration."
    raise "Production safety check failed: relative_url_root must not be set in production"
  end

  # Log current subpath configuration for development visibility
  if Rails.env.development?
    if config.relative_url_root.present?
      Rails.logger.info "✅ Rails application configured for subpath: #{config.relative_url_root}"
      Rails.logger.info "🔗 Application will be accessible at: http://localhost#{config.relative_url_root}/"
      Rails.logger.info "🔐 OAuth callbacks will use: http://localhost#{config.relative_url_root}/oauth2/callback"
    else
      Rails.logger.info "ℹ️  Rails application running on root path in development"
    end
  end
end

# Helper module for subpath-aware URL generation
module SubpathHelpers
  # Returns the application's base URL with subpath included
  def app_base_url(request = nil)
    if Rails.env.development? && Rails.application.config.relative_url_root.present?
      base = request ? "#{request.protocol}#{request.host_with_port}" : "http://localhost"
      "#{base}#{Rails.application.config.relative_url_root}"
    else
      request ? "#{request.protocol}#{request.host_with_port}" : "/"
    end
  end

  # Returns the OAuth callback URL with proper subpath handling
  def oauth_callback_url(request)
    "#{app_base_url(request)}/oauth2/callback"
  end

  # Generates subpath-aware URLs for development
  def subpath_aware_url(path, request = nil)
    if Rails.env.development? && Rails.application.config.relative_url_root.present?
      base = app_base_url(request)
      path = path.start_with?("/") ? path : "/#{path}"
      "#{base}#{path}"
    else
      path
    end
  end
end

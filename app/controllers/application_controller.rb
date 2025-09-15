class ApplicationController < ActionController::Base
  # Include subpath helpers for development environment - now available as module method
  # include SubpathHelpers

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Internationalization support
  before_action :set_locale

  private

  def set_locale
    # Priority order for locale detection:
    # 1. URL parameter (?locale=en)
    # 2. Session stored locale
    # 3. HTTP Accept-Language header
    # 4. Application default locale (pt-BR)

    locale = nil

    # Check URL parameter first
    if params[:locale].present? && I18n.available_locales.include?(params[:locale].to_sym)
      locale = params[:locale].to_sym
      # Store in session for persistence
      session[:locale] = locale
    # Check session
    elsif session[:locale].present? && I18n.available_locales.include?(session[:locale].to_sym)
      locale = session[:locale].to_sym
    # Check Accept-Language header
    elsif request.env["HTTP_ACCEPT_LANGUAGE"]
      # Extract language preferences from Accept-Language header
      accepted_languages = request.env["HTTP_ACCEPT_LANGUAGE"]
        .split(",")
        .map { |lang| lang.split(";").first.strip.to_sym }

      # Find first available locale from browser preferences
      locale = accepted_languages.find { |lang| I18n.available_locales.include?(lang) }
    end

    # Use detected locale or fallback to default
    I18n.locale = locale || I18n.default_locale
  end

  # Override url_for to ensure subpath-aware URLs in development
  def url_for(options = nil)
    return super(options) if @url_for_recursive_guard

    @url_for_recursive_guard = true
    begin
      if options.is_a?(Hash) && I18n.locale != I18n.default_locale
        options[:locale] = I18n.locale unless options.key?(:locale)
      end
      url = super(options)

      # Apply subpath in development environment only for relative URLs
      if Rails.env.development? && Rails.application.config.relative_url_root.present?
        subpath = Rails.application.config.relative_url_root
        # Only apply subpath to relative URLs that don't already have it
        if !url.start_with?("http") && !url.start_with?(subpath) && url.start_with?("/")
          url = "#{subpath}#{url}"
        end
      end

      url
    ensure
      @url_for_recursive_guard = false
    end
  end

  # Make current locale and subpath helpers available in views
  helper_method :current_locale, :app_root_url

  def current_locale
    I18n.locale
  end

  # Helper method for subpath-aware root URL generation
  def app_root_url
    if Rails.env.development? && Rails.application.config.relative_url_root
      root_url
    else
      root_url
    end
  end
end

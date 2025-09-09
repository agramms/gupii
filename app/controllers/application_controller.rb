class ApplicationController < ActionController::Base
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
    elsif request.env['HTTP_ACCEPT_LANGUAGE']
      # Extract language preferences from Accept-Language header
      accepted_languages = request.env['HTTP_ACCEPT_LANGUAGE']
        .split(',')
        .map { |lang| lang.split(';').first.strip.to_sym }
      
      # Find first available locale from browser preferences
      locale = accepted_languages.find { |lang| I18n.available_locales.include?(lang) }
    end
    
    # Use detected locale or fallback to default
    I18n.locale = locale || I18n.default_locale
  end
  
  # Helper method to generate URL with current locale
  def url_for(options = nil)
    if options.is_a?(Hash) && I18n.locale != I18n.default_locale
      options[:locale] = I18n.locale unless options.key?(:locale)
    end
    super(options)
  end
  
  # Make current locale available in views
  helper_method :current_locale
  
  def current_locale
    I18n.locale
  end
end

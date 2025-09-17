# AppConfig - Configuration Management with Environment and Credentials Fallback
#
# This class provides a unified way to access configuration values with the following priority:
# 1. Environment variables (e.g., DATABASE_URL)
# 2. Rails credentials (e.g., database.url)
# 3. Default value (if provided)
#
# Usage:
#   AppConfig.get('DATABASE_URL')                    # ENV['DATABASE_URL'] or Rails.application.credentials.database.url
#   AppConfig.get('OAUTH_CLIENT_ID', 'default')     # With fallback value
#   AppConfig.get('REDIS_MAX_CONNECTIONS', 10)      # With default integer
#   AppConfig.database_url                          # Method-based access
#
# Environment variable conversion to credentials path:
#   DATABASE_URL          → database.url
#   OAUTH_CLIENT_SECRET   → oauth.client_secret
#   JDPI_API_BASE_URL     → jdpi.api.base_url

class AppConfig
  class << self
    # Get configuration value with environment → credentials → default fallback
    def get(key, default = nil)
      # First, try environment variable
      env_value = ENV[key.to_s.upcase]
      return env_value if env_value.present?

      # Convert to credentials path and try Rails credentials
      credentials_path = env_key_to_credentials_path(key)
      credentials_value = dig_credentials(credentials_path)
      return credentials_value if credentials_value.present?

      # Return default value
      default
    end

    # Get configuration as boolean
    def get_boolean(key, default = false)
      value = get(key, default)
      return default if value.nil?

      case value.to_s.downcase
      when 'true', '1', 'yes', 'on'
        true
      when 'false', '0', 'no', 'off'
        false
      else
        !!default
      end
    end

    # Get configuration as integer
    def get_integer(key, default = 0)
      value = get(key, default)
      value.to_i
    end

    # Get configuration as array (comma-separated)
    def get_array(key, default = [])
      value = get(key)
      return default if value.blank?

      value.to_s.split(',').map(&:strip)
    end

    # Method-based access for dynamic configuration keys
    def method_missing(method_name, *args, &block)
      key = method_name.to_s.upcase
      if ENV.key?(key) || has_credentials_path?(env_key_to_credentials_path(key))
        get(key, args.first)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      key = method_name.to_s.upcase
      ENV.key?(key) || has_credentials_path?(env_key_to_credentials_path(key)) || super
    end

    private

    # Convert environment variable key to credentials path
    # DATABASE_URL → database.url
    # OAUTH_CLIENT_SECRET → oauth.client_secret
    # JDPI_API_BASE_URL → jdpi.api.base_url
    def env_key_to_credentials_path(key)
      key.to_s.downcase.split('_')
    end

    # Navigate through Rails credentials using array path
    def dig_credentials(path_array)
      return nil unless defined?(Rails) && Rails.application&.credentials&.present?

      path_array.reduce(Rails.application.credentials) do |current, key|
        return nil unless current.respond_to?(:[])
        current[key.to_sym]
      end
    rescue StandardError
      nil
    end

    # Check if credentials path exists
    def has_credentials_path?(path_array)
      dig_credentials(path_array).present?
    end
  end
end
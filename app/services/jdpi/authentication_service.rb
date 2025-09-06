module Jdpi
  # OAuth 2.0 authentication service for JDPI API
  # Handles token acquisition, caching, and refresh using Redis
  class AuthenticationService < BaseService
    include Jdpi::StatusCodes
    
    CACHE_KEY_PREFIX = "jdpi:token"
    TOKEN_REFRESH_THRESHOLD = Duration::TOKEN_REFRESH_THRESHOLD_SECONDS
    
    attr_accessor :scopes
    
    def initialize(scopes: ["dict_api", "spi_api", "qrcode_api"])
      super()
      @scopes = Array(scopes)
    end
    
    def call
      Rails.logger.info "[JDPI Auth] Requesting access token with scopes: #{scopes.join(', ')}"
      
      cached_token = fetch_cached_token
      return cached_token if cached_token && !token_expired?(cached_token)
      
      request_new_token
    end
    
    # Get valid access token, refreshing if necessary
    def access_token
      result = call
      return nil unless result
      
      result[:access_token]
    end
    
    # Check if token is valid and not expired
    def token_valid?(token = nil)
      token ||= fetch_cached_token
      return false unless token
      
      !token_expired?(token)
    end
    
    # Force token refresh
    def refresh_token!
      Rails.logger.info "[JDPI Auth] Force refreshing access token"
      clear_cached_token
      call
    end
    
    private
    
    def request_new_token
      response = oauth_client.post(Endpoints::AUTH_TOKEN) do |req|
        req.headers["Content-Type"] = "application/x-www-form-urlencoded"
        req.body = URI.encode_www_form({
          client_id: client_id,
          client_secret: client_secret,
          grant_type: "client_credentials",
          scope: scopes.join(",")
        })
      end
      
      result = handle_oauth_response(response)
      
      if result
        cache_token(result)
        Rails.logger.info "[JDPI Auth] Successfully obtained access token"
        result
      else
        Rails.logger.error "[JDPI Auth] Failed to obtain access token: #{errors.join(', ')}"
        nil
      end
    rescue Faraday::Error => e
      add_error("OAuth request failed: #{e.message}")
      nil
    end
    
    def handle_oauth_response(response)
      case response.status
      when 200
        token_data = response.body
        {
          access_token: token_data["access_token"],
          expires_in: token_data["expires_in"],
          token_type: token_data["token_type"],
          scope: token_data["scope"],
          expires_at: Time.current + token_data["expires_in"].seconds
        }
      when 400
        add_error("Invalid OAuth request: #{response.body&.dig('error_description') || 'Bad request'}")
        nil
      when 401
        add_error("Invalid client credentials")
        nil
      else
        add_error("OAuth error: HTTP #{response.status}")
        nil
      end
    end
    
    def oauth_client
      @oauth_client ||= Faraday.new(base_url) do |config|
        config.request :url_encoded
        config.response :json, content_type: /\bjson$/
        config.adapter Faraday.default_adapter
        config.options.timeout = 30
      end
    end
    
    def cache_token(token_data)
      cache_key = cache_key_for_scopes
      expires_in = token_data[:expires_in] - TOKEN_REFRESH_THRESHOLD
      
      redis.setex(cache_key, expires_in, token_data.to_json)
      
      Rails.logger.debug "[JDPI Auth] Token cached with key: #{cache_key}, expires in: #{expires_in}s"
    end
    
    def fetch_cached_token
      cache_key = cache_key_for_scopes
      cached_data = redis.get(cache_key)
      
      return nil unless cached_data
      
      token_data = JSON.parse(cached_data, symbolize_names: true)
      Rails.logger.debug "[JDPI Auth] Retrieved cached token: #{cache_key}"
      
      token_data
    rescue JSON::ParserError => e
      Rails.logger.error "[JDPI Auth] Failed to parse cached token: #{e.message}"
      clear_cached_token
      nil
    end
    
    def clear_cached_token
      cache_key = cache_key_for_scopes
      redis.del(cache_key)
      Rails.logger.debug "[JDPI Auth] Cleared cached token: #{cache_key}"
    end
    
    def token_expired?(token_data)
      return true unless token_data[:expires_at]
      
      Time.current >= token_data[:expires_at]
    end
    
    def cache_key_for_scopes
      scope_hash = Digest::MD5.hexdigest(scopes.sort.join(","))
      "#{CACHE_KEY_PREFIX}:#{scope_hash}"
    end
    
    def redis
      @redis ||= Redis.new(url: redis_url)
    end
    
    def redis_url
      Rails.application.credentials.redis&.dig(:url) || ENV["REDIS_URL"] || "redis://redis123@redis:6379/0"
    end
    
    def base_url
      Rails.application.credentials.jdpi&.dig(:base_url) || 
        ENV["JDPI_BASE_URL"] || 
        "https://api.jdpi.bcb.gov.br"
    end
    
    def client_id
      Rails.application.credentials.jdpi&.dig(:client_id) || 
        ENV["JDPI_CLIENT_ID"] || 
        raise(ArgumentError, "JDPI client_id not configured")
    end
    
    def client_secret
      Rails.application.credentials.jdpi&.dig(:client_secret) || 
        ENV["JDPI_CLIENT_SECRET"] || 
        raise(ArgumentError, "JDPI client_secret not configured")
    end
  end
end
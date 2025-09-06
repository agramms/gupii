module Jdpi
  class BaseService
    include ActiveModel::Model
    include StatusCodes
    
    attr_reader :response, :errors, :idempotency_key
    attr_accessor :scopes
    
    def initialize(attributes = {})
      @errors = []
      @scopes = attributes.delete(:scopes) || default_scopes
      super
    end
    
    def call
      raise NotImplementedError, "Subclasses must implement #call method"
    end
    
    def success?
      @errors.empty?
    end
    
    def failure?
      !success?
    end
    
    protected
    
    # HTTP client with automatic authentication and proper headers
    def client
      @client ||= Faraday.new(base_url) do |config|
        config.request :json
        config.response :json, content_type: /\bjson$/
        config.adapter Faraday.default_adapter
        config.options.timeout = StatusCodes::Network::DEFAULT_TIMEOUT_SECONDS
        config.options.open_timeout = StatusCodes::Network::DEFAULT_OPEN_TIMEOUT_SECONDS
        
        # Authentication header
        if token = access_token
          config.headers["Authorization"] = "Bearer #{token}"
        end
        
        # Standard headers
        config.headers["Content-Type"] = "application/json"
        config.headers["User-Agent"] = "Gupii/1.0"
      end
    end
    
    # Execute authenticated request with idempotency support
    def execute_request(method, path, body: nil, idempotent: false)
      prepare_idempotency_key if idempotent
      
      response = client.send(method, path) do |req|
        req.headers["Chave-Idempotencia"] = @idempotency_key if @idempotency_key
        req.body = body if body
      end
      
      handle_response(response)
    end
    
    # Get valid access token from authentication service
    def access_token
      auth_service = AuthenticationService.new(scopes: scopes)
      token = auth_service.access_token
      
      if token.nil? && auth_service.failure?
        auth_service.errors.each { |error| add_error("Auth: #{error}") }
      end
      
      token
    end
    
    # Handle JDPI API response according to documentation patterns
    def handle_response(response)
      @response = response
      
      case response.status
      when 200
        # Successful response
        response.body
      when 202
        # Accepted - async processing (common in JDPI)
        response.body
      when 400
        # Bad request
        error_msg = extract_error_message(response.body)
        add_error("Bad request: #{error_msg}")
        nil
      when 401
        # Unauthorized - token may be expired
        add_error("Unauthorized: token may be expired or invalid")
        nil
      when 403
        # Forbidden
        add_error("Forbidden: insufficient permissions")
        nil
      when 404
        # Not found - may indicate processing not complete in distributed system
        add_error("Resource not found - transaction may still be processing")
        nil
      when 405
        # Method not allowed
        add_error("Method not allowed")
        nil
      when 408
        # Request timeout
        add_error("Request timeout")
        nil
      when 409
        # Conflict - often idempotency related
        add_error("Conflict: request may be duplicate or invalid state")
        nil
      when 500..599
        # Server errors
        error_msg = extract_error_message(response.body)
        add_error("Server error (#{response.status}): #{error_msg}")
        nil
      else
        add_error("Unexpected response status: #{response.status}")
        nil
      end
    rescue Faraday::Error => e
      add_error("Network error: #{e.message}")
      nil
    end
    
    # Extract error message from JDPI response format
    def extract_error_message(response_body)
      return "Unknown error" unless response_body.is_a?(Hash)
      
      # JDPI error response format
      response_body["descCodigoErro"] || 
        response_body["message"] || 
        response_body["error_description"] ||
        "API error"
    end
    
    # Generate and store idempotency key
    def prepare_idempotency_key
      @idempotency_key = IdempotencyService.create_key({
        service: self.class.name,
        created_at: Time.current.iso8601
      })
    end
    
    def add_error(message)
      @errors << message
      Rails.logger.error "[JDPI] #{self.class.name}: #{message}"
    end
    
    # Configuration methods
    def base_url
      Rails.application.credentials.jdpi&.dig(:base_url) || 
        ENV["JDPI_BASE_URL"] || 
        "https://api.jdpi.bcb.gov.br"
    end
    
    def default_scopes
      ["spi_api"] # Default scope for SPI operations (payment refunds, etc.)
      # Available scopes:
      # - "dict_api": DICT operations (key management, infractions, refund requests)
      # - "spi_api": SPI operations (payment refunds, credit queries)  
      # - "qrcode_api": QR Code operations (static/dynamic codes)
    end
  end
end
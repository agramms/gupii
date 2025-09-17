# frozen_string_literal: true

module Jdpi
  class BaseService
    include ActiveModel::Model
    include Jdpi::StatusCodes

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
        config.options.timeout = Network::DEFAULT_TIMEOUT_SECONDS
        config.options.open_timeout = Network::DEFAULT_OPEN_TIMEOUT_SECONDS

        # Authentication header
        if token = access_token
          config.headers["Authorization"] = "Bearer #{token}"
        end

        # Standard headers
        config.headers["Content-Type"] = "application/json"
        config.headers["User-Agent"] = "Gupii/1.0"
      end
    end

    # Execute authenticated request with idempotency support and comprehensive logging
    def execute_request(method, path, body: nil, idempotent: false, pi_payer_id: nil)
      prepare_idempotency_key if idempotent

      # Generate request ID for tracking
      request_id = SecureRandom.hex(8)

      # Log request details
      log_request_start(request_id, method, path, body, pi_payer_id)

      start_time = Time.current

      begin
        response = client.send(method, path) do |req|
          req.headers["Chave-Idempotencia"] = @idempotency_key if @idempotency_key
          req.headers["PI-PayerId"] = pi_payer_id || BusinessRules::DEFAULT_PI_PAYER_ID
          req.headers["X-Request-ID"] = request_id
          req.body = body if body
        end

        duration = ((Time.current - start_time) * 1000).round(2) # Convert to milliseconds

        # Log successful response
        log_response_success(request_id, response, duration)

        handle_response(response)

      rescue Faraday::Error => e
        duration = ((Time.current - start_time) * 1000).round(2)
        log_request_error(request_id, e, duration)
        add_error("Network error: #{e.message}")
        nil
      rescue StandardError => e
        duration = ((Time.current - start_time) * 1000).round(2)
        log_request_error(request_id, e, duration)
        add_error("Unexpected error: #{e.message}")
        nil
      end
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
        Rails.logger.info "[JDPI] #{self.class.name}: Response handled successfully (200 OK)"
        response.body
      when 202
        # Accepted - async processing (common in JDPI)
        Rails.logger.info "[JDPI] #{self.class.name}: Request accepted for async processing (202 Accepted)"
        response.body
      when 400
        # Bad request
        error_msg = extract_error_message(response.body)
        Rails.logger.warn "[JDPI] #{self.class.name}: Bad request (400) - #{error_msg}"
        add_error("Bad request: #{error_msg}")
        nil
      when 401
        # Unauthorized - token may be expired
        Rails.logger.warn "[JDPI] #{self.class.name}: Unauthorized access (401) - token may be expired"
        add_error("Unauthorized: token may be expired or invalid")
        nil
      when 403
        # Forbidden
        Rails.logger.warn "[JDPI] #{self.class.name}: Forbidden access (403) - insufficient permissions"
        add_error("Forbidden: insufficient permissions")
        nil
      when 404
        # Not found - may indicate processing not complete in distributed system
        Rails.logger.warn "[JDPI] #{self.class.name}: Resource not found (404) - may still be processing"
        add_error("Resource not found - transaction may still be processing")
        nil
      when 405
        # Method not allowed
        Rails.logger.warn "[JDPI] #{self.class.name}: Method not allowed (405)"
        add_error("Method not allowed")
        nil
      when 408
        # Request timeout
        Rails.logger.warn "[JDPI] #{self.class.name}: Request timeout (408)"
        add_error("Request timeout")
        nil
      when 409
        # Conflict - often idempotency related
        Rails.logger.warn "[JDPI] #{self.class.name}: Conflict detected (409) - possible duplicate request"
        add_error("Conflict: request may be duplicate or invalid state")
        nil
      when 500..599
        # Server errors
        error_msg = extract_error_message(response.body)
        Rails.logger.error "[JDPI] #{self.class.name}: Server error (#{response.status}) - #{error_msg}"
        add_error("Server error (#{response.status}): #{error_msg}")
        nil
      else
        Rails.logger.error "[JDPI] #{self.class.name}: Unexpected response status #{response.status}"
        add_error("Unexpected response status: #{response.status}")
        nil
      end
    rescue Faraday::Error => e
      Rails.logger.error "[JDPI] #{self.class.name}: Network error during response handling - #{e.message}"
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
        created_at: Time.current.iso8601,
      })
    end

    def add_error(message)
      @errors << message
      Rails.logger.error "[JDPI] #{self.class.name}: #{message}"
    end

    private

    # Log request start with sanitized details
    def log_request_start(request_id, method, path, body, pi_payer_id)
      Rails.logger.info "[JDPI] #{self.class.name} [#{request_id}] REQUEST START: #{method.upcase} #{full_url(path)}"
      Rails.logger.info "[JDPI] #{self.class.name} [#{request_id}] Headers: PI-PayerId=#{pi_payer_id || 'default'}, Idempotency=#{@idempotency_key ? 'present' : 'none'}"

      if body.present?
        # Sanitize sensitive data before logging
        sanitized_body = sanitize_request_body(body)
        Rails.logger.info "[JDPI] #{self.class.name} [#{request_id}] Request Body: #{sanitized_body.to_json}"
      else
        Rails.logger.info "[JDPI] #{self.class.name} [#{request_id}] Request Body: none"
      end
    end

    # Log successful response with timing
    def log_response_success(request_id, response, duration_ms)
      Rails.logger.info "[JDPI] #{self.class.name} [#{request_id}] RESPONSE SUCCESS: #{response.status} in #{duration_ms}ms"
      Rails.logger.info "[JDPI] #{self.class.name} [#{request_id}] Response Headers: Content-Type=#{response.headers['content-type']}, Content-Length=#{response.headers['content-length'] || 'unknown'}"

      if response.body.present?
        # Sanitize sensitive data before logging response
        sanitized_response = sanitize_response_body(response.body)
        body_preview = sanitized_response.is_a?(String) ? sanitized_response[0..500] : sanitized_response.to_json[0..500]
        Rails.logger.info "[JDPI] #{self.class.name} [#{request_id}] Response Body Preview: #{body_preview}#{'...' if body_preview.length >= 500}"
      else
        Rails.logger.info "[JDPI] #{self.class.name} [#{request_id}] Response Body: empty"
      end
    end

    # Log request errors with timing and context
    def log_request_error(request_id, error, duration_ms)
      Rails.logger.error "[JDPI] #{self.class.name} [#{request_id}] REQUEST ERROR after #{duration_ms}ms: #{error.class.name} - #{error.message}"

      if error.respond_to?(:response) && error.response
        Rails.logger.error "[JDPI] #{self.class.name} [#{request_id}] Error Response Status: #{error.response.status}"
        Rails.logger.error "[JDPI] #{self.class.name} [#{request_id}] Error Response Body: #{error.response.body}"
      end

      # Log stack trace for debugging (only first 10 lines to avoid spam)
      if Rails.env.development? || Rails.logger.level <= Logger::DEBUG
        Rails.logger.debug "[JDPI] #{self.class.name} [#{request_id}] Stack trace:"
        error.backtrace&.first(10)&.each { |line| Rails.logger.debug "[JDPI] #{self.class.name} [#{request_id}]   #{line}" }
      end
    end

    # Build full URL for logging
    def full_url(path)
      "#{base_url}#{path}"
    end

    # Sanitize request body to remove sensitive information
    def sanitize_request_body(body)
      return body unless body.is_a?(Hash)

      sanitized = body.deep_dup

      # Remove or mask sensitive fields commonly found in JDPI requests
      sensitive_fields = %w[
        password senha token access_token refresh_token
        cpf cnpj account_number conta numero_conta
        chave_pix pix_key key endereco_conta
        nome_completo full_name
      ]

      sanitize_hash_fields(sanitized, sensitive_fields)
    end

    # Sanitize response body to remove sensitive information
    def sanitize_response_body(body)
      return body unless body.is_a?(Hash)

      sanitized = body.deep_dup

      # Remove or mask sensitive fields commonly found in JDPI responses
      sensitive_fields = %w[
        cpf cnpj account_number conta numero_conta
        chave_pix pix_key key endereco_conta
        nome_completo full_name nome
        agencia branch_code
      ]

      sanitize_hash_fields(sanitized, sensitive_fields)
    end

    # Helper method to sanitize hash fields
    def sanitize_hash_fields(hash, sensitive_fields)
      hash.each do |key, value|
        case value
        when Hash
          sanitize_hash_fields(value, sensitive_fields)
        when String
          if sensitive_fields.any? { |field| key.to_s.downcase.include?(field.downcase) }
            hash[key] = mask_sensitive_value(value)
          end
        when Array
          value.each { |item| sanitize_hash_fields(item, sensitive_fields) if item.is_a?(Hash) }
        end
      end

      hash
    end

    # Mask sensitive values while preserving format information
    def mask_sensitive_value(value)
      return value if value.blank?

      case value.length
      when 0..2
        "*" * value.length
      when 3..8
        "#{value[0]}#{'*' * (value.length - 2)}#{value[-1]}"
      else
        "#{value[0..1]}#{'*' * (value.length - 4)}#{value[-2..-1]}"
      end
    end

    # Configuration methods
    def base_url
      Rails.application.credentials.jdpi&.dig(:base_url) ||
        AppConfig.get("JDPI_BASE_URL") ||
        "https://api.jdpi.bcb.gov.br"
    end

    def default_scopes
      [ "spi_api" ] # Default scope for SPI operations (payment refunds, etc.)
      # Available scopes:
      # - "dict_api": DICT operations (key management, infractions, refund requests)
      # - "spi_api": SPI operations (payment refunds, credit queries)
      # - "qrcode_api": QR Code operations (static/dynamic codes)
    end
  end
end

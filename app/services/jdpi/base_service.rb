module Jdpi
  class BaseService
    include ActiveModel::Model
    
    BASE_URL = ENV.fetch("JDPI_BASE_URL", "https://api.jdpi.bcb.gov.br")
    
    attr_reader :response, :errors
    
    def initialize(attributes = {})
      @errors = []
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
    
    def client
      @client ||= Faraday.new(BASE_URL) do |config|
        config.request :json
        config.response :json, content_type: /\bjson$/
        config.adapter Faraday.default_adapter
        config.headers["Authorization"] = "Bearer #{access_token}" if access_token
        config.headers["Content-Type"] = "application/json"
      end
    end
    
    def access_token
      # TODO: Implement JWT token management for JDPI API
      ENV["JDPI_ACCESS_TOKEN"]
    end
    
    def handle_response(response)
      @response = response
      
      case response.status
      when 200..299
        response.body
      when 400..499
        add_error("Client error: #{response.body&.dig('message') || 'Bad request'}")
        nil
      when 500..599
        add_error("Server error: #{response.body&.dig('message') || 'Internal server error'}")
        nil
      else
        add_error("Unexpected response status: #{response.status}")
        nil
      end
    rescue Faraday::Error => e
      add_error("Network error: #{e.message}")
      nil
    end
    
    def add_error(message)
      @errors << message
      Rails.logger.error "[JDPI] #{self.class.name}: #{message}"
    end
  end
end
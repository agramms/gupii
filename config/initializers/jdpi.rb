# JDPI (Java Development Platform Integration) Configuration
# Configuration for PIX payment system integration via JDPI API

module Jdpi
  class Configuration
    attr_accessor :base_url, :client_id, :client_secret, :ispb,
                  :redis_url, :timeout, :open_timeout, :environment
    
    def initialize
      @environment = Rails.env
      @base_url = determine_base_url
      @timeout = 60
      @open_timeout = 30
    end
    
    private
    
    def determine_base_url
      case @environment
      when 'production'
        'https://api.jdpi.bcb.gov.br'
      when 'staging'  
        'https://api-hml.jdpi.bcb.gov.br'
      else
        'https://api-sandbox.jdpi.bcb.gov.br'
      end
    end
  end
  
  class << self
    attr_accessor :configuration
    
    def configuration
      @configuration ||= Configuration.new
    end
    
    def configure
      yield(configuration)
    end
    
    def reset_configuration
      @configuration = Configuration.new
    end
  end
end

# Configure JDPI with Rails credentials or environment variables
Jdpi.configure do |config|
  # Base URL based on environment
  config.base_url = Rails.application.credentials.jdpi&.dig(:base_url) || 
                   ENV['JDPI_BASE_URL'] || 
                   config.base_url
                   
  # OAuth2 credentials
  config.client_id = Rails.application.credentials.jdpi&.dig(:client_id) || 
                    ENV['JDPI_CLIENT_ID']
                    
  config.client_secret = Rails.application.credentials.jdpi&.dig(:client_secret) || 
                        ENV['JDPI_CLIENT_SECRET']
                        
  # Institution ISPB (8-digit code)
  config.ispb = Rails.application.credentials.jdpi&.dig(:ispb) || 
               ENV['JDPI_ISPB']
               
  # Redis configuration
  config.redis_url = Rails.application.credentials.redis&.dig(:url) || 
                    ENV['REDIS_URL'] || 
                    'redis://redis123@redis:6379/0'
                    
  # HTTP timeouts
  config.timeout = (ENV['JDPI_TIMEOUT'] || 60).to_i
  config.open_timeout = (ENV['JDPI_OPEN_TIMEOUT'] || 30).to_i
end

# Validate configuration in non-test environments
unless Rails.env.test?
  missing_configs = []
  
  missing_configs << 'JDPI_CLIENT_ID' unless Jdpi.configuration.client_id.present?
  missing_configs << 'JDPI_CLIENT_SECRET' unless Jdpi.configuration.client_secret.present?
  missing_configs << 'JDPI_ISPB' unless Jdpi.configuration.ispb.present?
  
  if missing_configs.any?
    Rails.logger.warn "[JDPI Config] Missing configurations: #{missing_configs.join(', ')}"
    Rails.logger.warn "[JDPI Config] Set these via Rails credentials or environment variables"
  end
end

# Log configuration (excluding secrets)
Rails.logger.info "[JDPI Config] Environment: #{Jdpi.configuration.environment}"
Rails.logger.info "[JDPI Config] Base URL: #{Jdpi.configuration.base_url}"
Rails.logger.info "[JDPI Config] ISPB: #{Jdpi.configuration.ispb || 'NOT_SET'}"
Rails.logger.info "[JDPI Config] Client ID: #{Jdpi.configuration.client_id ? 'SET' : 'NOT_SET'}"
Rails.logger.info "[JDPI Config] Client Secret: #{Jdpi.configuration.client_secret ? 'SET' : 'NOT_SET'}"
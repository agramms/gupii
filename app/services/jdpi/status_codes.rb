module Jdpi
  # JDPI Status Codes and Constants Module
  # Centralizes all status codes, error codes, and business constants used across JDPI services
  # Replaces magic numbers and strings with descriptive, maintainable constants
  module StatusCodes
    
    # Network and HTTP timeout constants
    module Network
      DEFAULT_TIMEOUT_SECONDS = 60
      DEFAULT_OPEN_TIMEOUT_SECONDS = 30
      AUTH_TIMEOUT_SECONDS = 10  
      OAUTH_TIMEOUT_SECONDS = 30
      LONG_OPERATION_TIMEOUT_SECONDS = 120
      RETRY_ATTEMPTS = 3
      RETRY_DELAY_SECONDS = 2
    end
    
    # JDPI API Response Status Codes
    module JdpiResponse
      # Legacy string codes
      SUCCESS = "00"
      KEY_NOT_FOUND = "01"
      KEY_ALREADY_EXISTS = "02"
      INVALID_KEY_FORMAT = "03"
      UNSUPPORTED_KEY_TYPE = "04"
      KEY_LIMIT_EXCEEDED = "05"
      INVALID_ACCOUNT = "06"
      UNAUTHORIZED_INSTITUTION = "07"
      TRANSACTION_NOT_FOUND = "08"
      INVALID_VALUE = "09"
      INVALID_DATETIME = "10"
      INVALID_SIGNATURE = "11"
      INVALID_CERTIFICATE = "12"
      SYSTEM_ERROR = "99"
      
      # Numeric status codes
      PROCESSING_ERROR = -1          # Erro no processamento
      ACCEPTED_AWAITING = 0          # Aceita aguardando processamento
      SUCCESS_COMPLETED = 9          # Processada com sucesso
      VALIDATION_ERROR = 400         # Erro de validação
      AUTHENTICATION_ERROR = 401    # Erro de autenticação
      AUTHORIZATION_ERROR = 403     # Erro de autorização
      NOT_FOUND_ERROR = 404         # Recurso não encontrado
      CONFLICT_ERROR = 409          # Conflito de estado
      INTERNAL_SERVER_ERROR = 500   # Erro interno do servidor
    end
    
    # Transaction Status Codes
    module TransactionStatus
      PROCESSING = 0
      SUCCESS = 9
      ERROR = -1
    end
    
    # HTTP Status Codes
    module HttpStatus
      OK = 200
      CREATED = 201
      ACCEPTED = 202
      NO_CONTENT = 204
      BAD_REQUEST = 400
      UNAUTHORIZED = 401
      FORBIDDEN = 403
      NOT_FOUND = 404
      METHOD_NOT_ALLOWED = 405
      REQUEST_TIMEOUT = 408
      CONFLICT = 409
      UNPROCESSABLE_ENTITY = 422
      TOO_MANY_REQUESTS = 429
      INTERNAL_SERVER_ERROR = 500
      BAD_GATEWAY = 502
      SERVICE_UNAVAILABLE = 503
      GATEWAY_TIMEOUT = 504
    end
    
    # PIX Key Types and Validation Patterns
    module PixKeyTypes
      CPF_PATTERN = /\A\d{11}\z/
      CNPJ_PATTERN = /\A\d{14}\z/
      EMAIL_PATTERN = /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/
      PHONE_PATTERN = /\A\+55\d{10,11}\z/
      UUID_PATTERN = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
      
      TYPES = {
        cpf: { pattern: CPF_PATTERN, description: 'CPF - 11 digits' },
        cnpj: { pattern: CNPJ_PATTERN, description: 'CNPJ - 14 digits' },
        email: { pattern: EMAIL_PATTERN, description: 'Email address' },
        phone: { pattern: PHONE_PATTERN, description: 'Phone with +55 prefix' },
        uuid: { pattern: UUID_PATTERN, description: 'UUID format' }
      }.freeze
    end
    
    # Infraction Types as defined by Central Bank
    module InfractionTypes
      FRAUD = 'FRAUD'
      AML_VIOLATION = 'AML_VIOLATION'
      ACCOUNT_MISUSE = 'ACCOUNT_MISUSE'
      INVALID_KEY = 'INVALID_KEY'
      UNAUTHORIZED_USE = 'UNAUTHORIZED_USE'
      
      DESCRIPTIONS = {
        FRAUD => 'Fraudulent activity detection',
        AML_VIOLATION => 'Anti-money laundering violations',
        ACCOUNT_MISUSE => 'Inappropriate account usage',
        INVALID_KEY => 'PIX key validation issues',
        UNAUTHORIZED_USE => 'Usage without proper authorization'
      }.freeze
      
      ALL = DESCRIPTIONS.keys.freeze
    end
    
    # Infraction Notification Sources
    module InfractionSources
      CUSTOMER_SERVICE = 'CUSTOMER_SERVICE'
      CUSTOMER_EXPERIENCE = 'CUSTOMER_EXPERIENCE'
      DICT_AUTOMATIC = 'DICT_AUTOMATIC'
      
      DESCRIPTIONS = {
        CUSTOMER_SERVICE => 'Customer Service Department',
        CUSTOMER_EXPERIENCE => 'Customer Experience Department',
        DICT_AUTOMATIC => 'Automatic DICT System'
      }.freeze
      
      ALL = DESCRIPTIONS.keys.freeze
    end
    
    # Infraction Status Lifecycle
    module InfractionStatus
      SUBMITTED = 'SUBMITTED'
      PROCESSING = 'PROCESSING'
      ANALYZING = 'ANALYZING'
      APPROVED = 'APPROVED'
      REJECTED = 'REJECTED'
      COMPLETED = 'COMPLETED'
      CANCELLED = 'CANCELLED'
      
      ALL = [SUBMITTED, PROCESSING, ANALYZING, APPROVED, REJECTED, COMPLETED, CANCELLED].freeze
      
      DESCRIPTIONS = {
        SUBMITTED => 'Submetido',
        PROCESSING => 'Processando',
        ANALYZING => 'Analisando',
        APPROVED => 'Aprovado',
        REJECTED => 'Rejeitado',
        COMPLETED => 'Concluído',
        CANCELLED => 'Cancelado'
      }.freeze
      
      # Valid status transitions
      TRANSITIONS = {
        SUBMITTED => [PROCESSING, CANCELLED],
        PROCESSING => [ANALYZING, REJECTED, CANCELLED],
        ANALYZING => [APPROVED, REJECTED, CANCELLED],
        APPROVED => [COMPLETED],
        REJECTED => [COMPLETED],
        CANCELLED => [],
        COMPLETED => []
      }.freeze
    end
    
    # Analysis Results for Infraction Review
    module AnalysisResults
      CONFIRMED = 'CONFIRMED'
      REJECTED = 'REJECTED'
      NEEDS_MORE_INFO = 'NEEDS_MORE_INFO'
      
      ALL = [CONFIRMED, REJECTED, NEEDS_MORE_INFO].freeze
      
      DESCRIPTIONS = {
        CONFIRMED => 'Infraction confirmed - action required',
        REJECTED => 'Infraction rejected - no action needed',
        NEEDS_MORE_INFO => 'Additional information required for analysis'
      }.freeze
    end
    
    # API Scopes for Different JDPI Operations
    module ApiScopes
      DICT_API = 'dict_api'               # DICT operations (key management, infractions)
      SPI_API = 'spi_api'                 # SPI operations (payments, refunds)
      QRCODE_API = 'qrcode_api'           # QR Code operations
      SPI_WEBHOOK_API = 'spi_webhook_api' # Webhook notifications
      SPIAUT_API = 'spiaut_api'           # SPI authentication
      SPIAGE_API = 'spiage_api'           # SPI agent operations
      
      BOTH = [DICT_API, SPI_API]          # For operations requiring both scopes
      ALL = [DICT_API, SPI_API, QRCODE_API, SPI_WEBHOOK_API, SPIAUT_API, SPIAGE_API].freeze
      
      # Scope descriptions
      DESCRIPTIONS = {
        DICT_API => 'DICT API access for PIX key management and infractions',
        SPI_API => 'SPI API access for payment processing and refunds',
        QRCODE_API => 'QR Code generation and management',
        SPI_WEBHOOK_API => 'Webhook notification handling',
        SPIAUT_API => 'SPI authentication operations',
        SPIAGE_API => 'SPI agent operations'
      }.freeze
    end
    
    # Business Rule Constants
    module BusinessRules
      MAX_DESCRIPTION_LENGTH = 500
      MAX_ANALYSIS_NOTES_LENGTH = 1000
      MAX_PAGINATION_LIMIT = 100
      DEFAULT_PAGINATION_LIMIT = 50
      MAX_EVIDENCE_FILES = 10
      MAX_EVIDENCE_FILE_SIZE_MB = 50
      
      # Default PI-PayerId (Bank Institution CNPJ)
      DEFAULT_PI_PAYER_ID = '15111975000164'  # 15.111.975/0001-64
      
      # Default ISPB (Institution's Identifier in SFN)
      DEFAULT_ISPB = '15111975'  # Bank's ISPB code
    end
    
    # Time and Duration Constants
    module Duration
      TOKEN_CACHE_TTL_SECONDS = 3300        # 55 minutes (tokens expire in 1h)
      TOKEN_REFRESH_THRESHOLD_SECONDS = 300 # Refresh token 5 minutes before expiry
      CACHE_EXPIRY_SECONDS = 1200           # 20 minutes default cache
      IDEMPOTENCY_TTL_SECONDS = 86400       # 24 hours
      IDEMPOTENCY_CACHE_TTL_SECONDS = 86400 # 24 hours (alias for consistency)
      MAX_REFUND_WINDOW_DAYS = 90           # Maximum days for refund requests
      MAX_ANALYSIS_DAYS = 30                # Maximum days to analyze infractions
    end
    
    # Risk Assessment Constants  
    module Risk
      LOW_RISK_THRESHOLD = 0.3
      MEDIUM_RISK_THRESHOLD = 0.6
      HIGH_RISK_THRESHOLD = 0.8
      CRITICAL_RISK_THRESHOLD = 0.95
      
      DEFAULT_LOW_RISK_SCORE = 0.1
      DEFAULT_MEDIUM_RISK_SCORE = 0.5
      DEFAULT_HIGH_RISK_SCORE = 0.9
      
      FRAUD_RISK_SCORE_THRESHOLD = HIGH_RISK_THRESHOLD
    end
    
    # MED Refund Reason Codes
    module MedReasonCodes
      OPERATIONAL_FAILURE = "BE08"  # Falha operacional
      FRAUD_SUSPICION = "FR01"      # Suspeita de fraude
      USER_REQUESTED = "MD06"       # Solicitação do usuário
      SAQUE_TROCO_ERROR = "SL02"    # Erro PIX Saque/Troco
      
      ALL = [OPERATIONAL_FAILURE, FRAUD_SUSPICION, USER_REQUESTED, SAQUE_TROCO_ERROR].freeze
      
      DESCRIPTIONS = {
        OPERATIONAL_FAILURE => 'Operational failure refund',
        FRAUD_SUSPICION => 'Fraud suspicion refund', 
        USER_REQUESTED => 'User requested refund',
        SAQUE_TROCO_ERROR => 'PIX Cash withdrawal/Change error'
      }.freeze
    end
    
    # Validation Patterns
    module ValidationPatterns
      END_TO_END_ID = /\A[DE]\d{8}\d{8}\w{11}\z/  # E/D + ISPB(8) + DateTime(8) + Sequence(11)
      IDEMPOTENCY_KEY = /\A[\w-]{36}\z/            # 36-character GUID format
      PIX_KEY_CPF = /\A\d{11}\z/                   # CPF: 11 digits
      PIX_KEY_CNPJ = /\A\d{14}\z/                  # CNPJ: 14 digits
      PIX_KEY_PHONE = /\A\+55\d{10,11}\z/          # Phone: +55 + 10/11 digits
      PIX_KEY_EMAIL = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/ # Basic email format
      PIX_KEY_RANDOM = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i # UUID format
    end

    # JDPI API Endpoint Patterns
    module Endpoints
      # DICT API Base
      DICT_BASE = '/chave-gestao-api/jdpi/dict/api/v2'
      INFRACTION_BASE = '/chave-relato-infracao-api/jdpi/dict/api/v2'
      
      # SPI API Base  
      SPI_BASE = '/spi-api/jdpi/spi/api/v2'
      
      # Infraction endpoints
      INFRACTIONS = "#{INFRACTION_BASE}/relato-infracao"
      INFRACTION_PROCESSING = "#{INFRACTIONS}/pendentes"
      INFRACTION_LIST = "#{INFRACTIONS}/listar"
      INFRACTION_BY_ID = "#{INFRACTIONS}/consultar"  # Query params added at runtime
      INFRACTION_ANALYSIS = "#{INFRACTIONS}/%{notification_id}/analise"
      
      # Authentication
      AUTH_TOKEN = '/auth/jdpi/connect/token'
    end
    
    # Error Messages Templates
    module ErrorMessages
      VALIDATION_FAILED = 'Validation failed: %{errors}'
      AUTHENTICATION_FAILED = 'Authentication failed: %{message}'
      NETWORK_ERROR = 'Network error: %{message}'
      TIMEOUT_ERROR = 'Request timeout after %{seconds} seconds'
      INVALID_RESPONSE = 'Invalid response from JDPI API: %{message}'
      SERVICE_UNAVAILABLE = 'JDPI service temporarily unavailable'
      RATE_LIMIT_EXCEEDED = 'Rate limit exceeded, please try again later'
      
      # PIX Key specific errors
      INVALID_PIX_KEY_FORMAT = 'Invalid PIX key format for type: %{type}'
      PIX_KEY_NOT_FOUND = 'PIX key not found: %{key}'
      
      # Infraction specific errors
      INVALID_INFRACTION_TYPE = 'Invalid infraction type: %{type}'
      INFRACTION_NOT_FOUND = 'Infraction notification not found: %{id}'
      INFRACTION_ALREADY_CANCELLED = 'Infraction notification already cancelled'
      INFRACTION_CANNOT_BE_CANCELLED = 'Infraction notification cannot be cancelled in current state'
    end
    
    # Success Messages Templates
    module SuccessMessages
      INFRACTION_CREATED = 'Infraction notification created successfully: %{id}'
      INFRACTION_CANCELLED = 'Infraction notification cancelled successfully'
      INFRACTION_ANALYZED = 'Infraction notification analyzed: %{result}'
      FRAUD_MARKING_CREATED = 'Fraud marking created successfully: %{id}'
      FRAUD_MARKING_CANCELLED = 'Fraud marking cancelled successfully'
      FRAUD_MARKING_QUERIED = 'Fraud marking queried successfully: %{id}'
      AUTHENTICATION_SUCCESS = 'Successfully authenticated with JDPI API'
      TOKEN_REFRESHED = 'Access token refreshed successfully'
    end
    
    # Logging Constants
    module Logging
      SERVICE_PREFIX = '[JDPI'
      AUTH_TAG = 'Auth]'
      INFRACTION_TAG = 'Infraction]'
      BASE_TAG = 'Service]'
      IDEMPOTENCY_TAG = 'Idempotency]'
      
      # Log levels
      INFO_OPERATIONS = %w[create list query refresh].freeze
      WARN_OPERATIONS = %w[cancel retry timeout].freeze
      ERROR_OPERATIONS = %w[fail exception authentication_error].freeze
    end
    
    # Utility Methods
    module Utils
      def self.valid_status_transition?(from_status, to_status)
        return false if from_status.blank? || to_status.blank?
        InfractionStatus::TRANSITIONS.fetch(from_status, []).include?(to_status)
      end
      
      def self.valid_pix_key?(key)
        return false if key.blank?
        PixKeyTypes::TYPES.any? { |_, config| key.match?(config[:pattern]) }
      end
      
      def self.detect_pix_key_type(key)
        return nil if key.blank?
        PixKeyTypes::TYPES.find { |_, config| key.match?(config[:pattern]) }&.first
      end
      
      def self.valid_infraction_type?(type)
        InfractionTypes::ALL.include?(type.to_s.upcase)
      end
      
      def self.valid_analysis_result?(result)
        AnalysisResults::ALL.include?(result.to_s.upcase)
      end
      
      def self.mask_sensitive_data(data, type = :pix_key)
        return data if data.blank?
        
        case type
        when :pix_key
          mask_pix_key(data)
        when :token
          data.length > 20 ? "#{data[0..10]}...#{data[-6..-1]}" : data
        else
          data
        end
      end
      
      private
      
      def self.mask_pix_key(key)
        key_type = detect_pix_key_type(key)
        
        case key_type
        when :cpf
          key.gsub(/(\d{3})(\d{3})(\d{3})(\d{2})/, '\1.***.***-\4')
        when :cnpj
          key.gsub(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '\1.***.***/**\4-\5')
        when :email
          parts = key.split('@')
          if parts[0].length > 2
            masked_local = parts[0][0..1] + '*' * (parts[0].length - 2)
            "#{masked_local}@#{parts[1]}"
          else
            key
          end
        when :phone
          key.gsub(/(\+55)(\d{2})(\d+)(\d{4})/, '\1\2****\4')
        when :uuid
          key.length > 12 ? "#{key[0..7]}****#{key[-4..-1]}" : key
        else
          key
        end
      end
      
      # Get ISPB value from configuration or environment with fallback to default
      def self.ispb_value
        if defined?(Rails)
          Rails.application.credentials.jdpi&.dig(:ispb) || 
            ENV['JDPI_ISPB'] || 
            BusinessRules::DEFAULT_ISPB
        else
          BusinessRules::DEFAULT_ISPB
        end
      end
    end
  end
end
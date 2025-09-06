module Jdpi
  # JDPI Status Codes Constants
  # Centralizes all magic numbers for JDPI API responses according to v5.2.1 specification
  module StatusCodes
    # Primary status codes (stJdPi) - Main transaction status
    ST_JDPI = {
      PROCESSING_ERROR: -1,           # Erro no processamento
      ACCEPTED_AWAITING: 0,           # Requisição aceita no JDPI, aguardando processamento
      SUCCESS_COMPLETED: 9            # Débito/crédito efetivado com sucesso
    }.freeze
    
    # Processing status codes (stJdPiProc) - Intermediate processing status  
    ST_JDPI_PROC = {
      ACCEPTED_AWAITING: 0,           # Requisição aceita no JDPI, aguardando processamento
      IN_PROCESSING: 1,               # Em processamento
      SENT_TO_SPI_AWAITING: 2,        # Enviada ao SPI, aguardando retorno
      NO_SPI_RESPONSE: 5,             # JDPI não recebeu retorno do SPI ou retorno não terminativo
      JDPI_VALIDATION_ERROR: 7,       # Erro de validação no JDPI
      SPI_ERROR: 8,                   # Erro retornado pelo SPI
      SUCCESS_PROCESSED: 9            # Débito/crédito processado com sucesso
    }.freeze
    
    # Grouped status collections for easier checking
    FINAL_SUCCESS_STATES = [
      ST_JDPI[:SUCCESS_COMPLETED],
      ST_JDPI_PROC[:SUCCESS_PROCESSED]
    ].freeze
    
    FINAL_ERROR_STATES = [
      ST_JDPI[:PROCESSING_ERROR],
      ST_JDPI_PROC[:JDPI_VALIDATION_ERROR], 
      ST_JDPI_PROC[:SPI_ERROR]
    ].freeze
    
    PROCESSING_STATES = [
      ST_JDPI[:ACCEPTED_AWAITING],
      ST_JDPI_PROC[:ACCEPTED_AWAITING],
      ST_JDPI_PROC[:IN_PROCESSING],
      ST_JDPI_PROC[:SENT_TO_SPI_AWAITING],
      ST_JDPI_PROC[:NO_SPI_RESPONSE]
    ].freeze
    
    FINAL_STATES = (FINAL_SUCCESS_STATES + FINAL_ERROR_STATES).freeze
    
    # Status descriptions for logging and reporting
    STATUS_DESCRIPTIONS = {
      # ST_JDPI descriptions
      ST_JDPI[:PROCESSING_ERROR] => "Erro no processamento",
      ST_JDPI[:ACCEPTED_AWAITING] => "Requisição aceita, aguardando processamento",
      ST_JDPI[:SUCCESS_COMPLETED] => "Transação efetivada com sucesso",
      
      # ST_JDPI_PROC descriptions  
      ST_JDPI_PROC[:ACCEPTED_AWAITING] => "Requisição aceita, aguardando processamento",
      ST_JDPI_PROC[:IN_PROCESSING] => "Em processamento",
      ST_JDPI_PROC[:SENT_TO_SPI_AWAITING] => "Enviada ao SPI, aguardando retorno",
      ST_JDPI_PROC[:NO_SPI_RESPONSE] => "Sem retorno do SPI ou retorno não terminativo",
      ST_JDPI_PROC[:JDPI_VALIDATION_ERROR] => "Erro de validação no JDPI",
      ST_JDPI_PROC[:SPI_ERROR] => "Erro retornado pelo SPI",
      ST_JDPI_PROC[:SUCCESS_PROCESSED] => "Processado com sucesso"
    }.freeze
    
    # Polling configuration constants
    module Polling
      # Polling intervals (in seconds)
      INITIAL_POLL_INTERVALS = [5, 5, 10, 10, 30, 30].freeze    # First 40 seconds
      INTERMEDIATE_POLL_INTERVALS = [30].freeze                   # Standard polling (30s)
      LONG_TERM_POLL_INTERVALS = [300].freeze                   # Extended polling (5 minutes)
      
      # Polling periods
      INITIAL_PERIOD_SECONDS = 40
      INTERMEDIATE_PERIOD_SECONDS = 600  # 10 minutes
      
      # Retry configuration
      MAX_ERROR_RETRIES = 10
      MAX_EXPONENTIAL_BACKOFF_SECONDS = 300  # 5 minutes
      MAX_EXPONENTIAL_BACKOFF_POWER = 8
    end
    
    # Risk scoring constants
    module Risk
      LOW_RISK_THRESHOLD = 0.3
      MEDIUM_RISK_THRESHOLD = 0.6  
      HIGH_RISK_THRESHOLD = 0.8
      CRITICAL_RISK_THRESHOLD = 0.9
      
      # Fraud detection thresholds
      FRAUD_RISK_SCORE_THRESHOLD = 0.7
      MANUAL_REVIEW_THRESHOLD = 0.6
      
      # Placeholder risk scores
      DEFAULT_HIGH_RISK_SCORE = 0.8
    end
    
    # Time and duration constants
    module Duration
      TOKEN_REFRESH_THRESHOLD_SECONDS = 300        # 5 minutes before expiry
      IDEMPOTENCY_CACHE_TTL_SECONDS = 86400        # 24 hours
      MAX_REFUND_WINDOW_DAYS = 90                  # 90 days max refund window
      MAX_POLLING_DURATION_DAYS = 90               # 90 days max polling
      
      # PIX operation valid year range
      PIX_MIN_YEAR = 2020
      PIX_MAX_YEAR = 2099
    end
    
    # Transaction limits and thresholds
    module Limits
      MAX_TRANSACTIONS_PER_DAY = 100
      MAX_TRANSACTION_AMOUNT = 999_999_999_999_999.99
      DAILY_TRANSACTION_LIMIT = 100_000.00
      
      # Fraud detection amount thresholds
      REPORTING_THRESHOLDS = [10_000, 50_000, 100_000].freeze
      LARGE_AMOUNT_MULTIPLIER = 10
    end
    
    # HTTP and network configuration
    module Network
      DEFAULT_TIMEOUT_SECONDS = 60
      DEFAULT_OPEN_TIMEOUT_SECONDS = 30
      CONNECTION_POOL_SIZE = 25
      CONNECTION_POOL_TIMEOUT_SECONDS = 30
      
      # Retry attempts
      MAX_NETWORK_RETRIES = 5
      MAX_REDIS_RETRIES = 3
    end
    
    # Helper methods for status checking
    class << self
      def final_success?(st_jdpi: nil, st_jdpi_proc: nil)
        return false unless st_jdpi || st_jdpi_proc
        
        FINAL_SUCCESS_STATES.include?(st_jdpi) || 
        FINAL_SUCCESS_STATES.include?(st_jdpi_proc)
      end
      
      def final_error?(st_jdpi: nil, st_jdpi_proc: nil)
        return false unless st_jdpi || st_jdpi_proc
        
        FINAL_ERROR_STATES.include?(st_jdpi) || 
        FINAL_ERROR_STATES.include?(st_jdpi_proc)
      end
      
      def final_state?(st_jdpi: nil, st_jdpi_proc: nil)
        final_success?(st_jdpi: st_jdpi, st_jdpi_proc: st_jdpi_proc) ||
        final_error?(st_jdpi: st_jdpi, st_jdpi_proc: st_jdpi_proc)
      end
      
      def processing_state?(st_jdpi: nil, st_jdpi_proc: nil)
        return false unless st_jdpi || st_jdpi_proc
        
        PROCESSING_STATES.include?(st_jdpi) || 
        PROCESSING_STATES.include?(st_jdpi_proc)
      end
      
      def status_description(status_code)
        STATUS_DESCRIPTIONS[status_code] || "Unknown status: #{status_code}"
      end
      
      def risk_level(score)
        case score
        when 0..Risk::LOW_RISK_THRESHOLD
          :low
        when Risk::LOW_RISK_THRESHOLD..Risk::MEDIUM_RISK_THRESHOLD
          :medium
        when Risk::MEDIUM_RISK_THRESHOLD..Risk::HIGH_RISK_THRESHOLD
          :high
        else
          :critical
        end
      end
    end
  end
end
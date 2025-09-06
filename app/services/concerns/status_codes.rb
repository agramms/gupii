# frozen_string_literal: true

# Status codes and constants module for JDPI API integration
# Provides centralized constants for HTTP status codes, timeouts, and API response codes
module StatusCodes
  # Network timeout constants
  module Network
    DEFAULT_TIMEOUT_SECONDS = 60
    DEFAULT_OPEN_TIMEOUT_SECONDS = 30
    OAUTH_TIMEOUT_SECONDS = 30
  end

  # Token management constants
  module Duration
    TOKEN_REFRESH_THRESHOLD_SECONDS = 300 # Refresh token 5 minutes before expiry
    CACHE_EXPIRY_SECONDS = 1200 # 20 minutes default cache
  end

  # JDPI API response codes
  module JdpiResponse
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
  end

  # Transaction status codes
  module TransactionStatus
    PROCESSING = 0
    SUCCESS = 9
    ERROR = -1
  end

  # MED refund reason codes according to JDPI specification
  module MedReasonCodes
    OPERATIONAL_FAILURE = "BE08"  # Falha operacional
    FRAUD_SUSPICION = "FR01"      # Suspeita de fraude
    USER_REQUESTED = "MD06"       # Solicitação do usuário
    SAQUE_TROCO_ERROR = "SL02"    # Erro PIX Saque/Troco
  end

  # Infraction types for notification system
  module InfractionTypes
    FRAUD = "FRAUD"                    # Fraude
    AML_VIOLATION = "AML_VIOLATION"    # Violação de prevenção à lavagem de dinheiro
    ACCOUNT_MISUSE = "ACCOUNT_MISUSE"  # Uso indevido de conta
    INVALID_KEY = "INVALID_KEY"        # Chave PIX inválida
    UNAUTHORIZED_USE = "UNAUTHORIZED_USE" # Uso não autorizado
  end

  # Infraction notification status
  module InfractionStatus
    SUBMITTED = "SUBMITTED"           # Enviada
    PROCESSING = "PROCESSING"         # Em processamento
    ANALYZING = "ANALYZING"           # Em análise
    APPROVED = "APPROVED"             # Aprovada
    REJECTED = "REJECTED"             # Rejeitada
    CANCELLED = "CANCELLED"           # Cancelada
    COMPLETED = "COMPLETED"           # Concluída
  end

  # HTTP status codes for API responses
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

  # JDPI API scopes for OAuth2 authentication
  module ApiScopes
    DICT_API = "dict_api"           # DICT operations (key management, infractions)
    SPI_API = "spi_api"             # SPI operations (payments, refunds)
    QRCODE_API = "qrcode_api"       # QR Code operations
    SPI_WEBHOOK_API = "spi_webhook_api"  # Webhook notifications
    SPIAUT_API = "spiaut_api"       # SPI authentication
    SPIAGE_API = "spiage_api"       # SPI agent operations
  end

  # Common API endpoint patterns
  module EndpointPatterns
    DICT_BASE = "/jdpi/dict/api/v2"
    SPI_BASE = "/jdpi/spi/api/v2"
    OAUTH_TOKEN = "/jdpi/connect/token"
  end

  # Validation patterns
  module ValidationPatterns
    END_TO_END_ID = /\A[DE]\d{8}\d{8}\w{11}\z/  # E/D + ISPB(8) + DateTime(8) + Sequence(11)
    IDEMPOTENCY_KEY = /\A[\w-]{36}\z/            # 36-character GUID format
    PIX_KEY_CPF = /\A\d{11}\z/                   # CPF: 11 digits
    PIX_KEY_CNPJ = /\A\d{14}\z/                  # CNPJ: 14 digits
    PIX_KEY_PHONE = /\A\+55\d{10,11}\z/          # Phone: +55 + 10/11 digits
    PIX_KEY_EMAIL = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/ # Basic email format
    PIX_KEY_RANDOM = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i # UUID format
  end
end
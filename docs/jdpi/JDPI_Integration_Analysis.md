# JDPI Integration Analysis & Implementation Guide

## Overview

JDPI (Sistema Automatizado by JD Consultores) provides access to Brazil's PIX instant payment system through comprehensive APIs that connect to:
- **DICT** (Diretório de Identificadores de Contas Transacionais): PIX key management
- **SPI** (Sistema de Pagamentos Instantâneos): Payment processing and settlement

## Critical Integration Points

### 1. Authentication & Security
**OAuth 2.0 Client Credentials Flow**
```
POST /jdpi/connect/token
Content-Type: application/x-www-form-urlencoded

client_id=YOUR_CLIENT_ID&
client_secret=YOUR_SECRET&
grant_type=client_credentials&
scope=dict_api,spi_api,qrcode_api
```

**Key Requirements:**
- **Token Caching**: MUST implement caching with `expires_in` expiration
- **Scopes**: Multiple scopes available (dict_api, spi_api, qrcode_api, spi_webhook_api, spiaut_api, spiage_api)
- **Bearer Token**: Use `Authorization: Bearer {access_token}` in all API calls
- **Idempotency**: MUST implement with `Chave-Idempotencia` header (36-char GUID)

### 2. Core API Groups

#### A. DICT Key Management (`dict_api` scope)
**Critical Endpoints:**
- `POST /jdpi/dict/api/v2/chave` - Create PIX key
- `PUT /jdpi/dict/api/v2/chave/{chave}` - Update PIX key  
- `DELETE /jdpi/dict/api/v2/chave/{chave}` - Delete PIX key
- `GET /jdpi/dict/api/v2/consulta/{chave}` - Query PIX key
- `POST /jdpi/dict/api/v2/reivindicacao` - Claim PIX key

**PIX Key Types:**
- CPF/CNPJ
- Email  
- Phone (+5511999999999)
- Random UUID (EVP - Endereço Virtual de Pagamento)

#### B. Payment Execution (`spi_api` scope)
**Critical Endpoints:**
- `POST /jdpi/spi/api/v2/op` - Execute payment order
- `GET /jdpi/spi/api/v2/op/{idReqJdPiConsultada}` - Query payment status
- `GET /jdpi/spi/api/v2/credito-pagamento/{endToEndId}` - Query credit status
- `GET /jdpi/spi/api/v2/conta-transacional/{endToEndId}` - Get transaction details

#### C. Refunds/Returns (`spi_api` scope) - **MED FOCUS**
**Critical Endpoints for MED (Mecanismo Especial de Devolução):**
- `POST /jdpi/spi/api/v2/od` - Request refund
- `GET /jdpi/spi/api/v2/od/{idReqJdPiConsultada}` - Query refund status
- `GET /jdpi/spi/api/v2/od/motivos` - List refund reasons
- `GET /jdpi/spi/api/v2/credito-devolucao/{endToEndId}` - Query refund credit status

**MED Refund Codes:**
- **BE08**: Operational failure refund
- **FR01**: Fraud suspicion refund  
- **MD06**: User-requested refund
- **SL02**: PIX Saque/Troco error refund

### 3. Transaction Flow Architecture

#### Payment Flow
```
1. [Client] Query PIX Key → JDPI/DICT
2. [Client] Validate payment data
3. [Client] Request Payment → JDPI/SPI  
4. [JDPI] → Central Bank SPI
5. [JDPI] → Return status to Client
6. [Client] Poll for final status
```

#### Refund Flow (MED)
```
1. [Client] Validate refund eligibility (90-day limit)
2. [Client] Request Refund → JDPI/SPI
3. [JDPI] → Central Bank SPI
4. [JDPI] → Return refund status
5. [Client] Poll for confirmation
```

### 4. Technical Requirements

#### Idempotency Implementation
- **MUST** use 36-character GUID format
- **MUST** store and reuse for retries
- **MUST** include in `Chave-Idempotencia` header
- **CRITICAL**: Prevents duplicate transactions

#### Status Polling Pattern
- **Initial Response**: HTTP 202 (Accepted)
- **Polling Endpoint**: Query with `idReqJdPi`
- **Final States**: 
  - `stJdPi = 9` (Success)
  - `stJdPi = -1` (Error)
  - `stJdPi = 0` (Processing - continue polling)

#### Error Handling
- **Network Timeouts**: 40-80 second SPI processing window
- **404 Responses**: Transaction may still be processing in queue
- **Microservices Architecture**: Distributed events may cause delays

### 5. Compliance & Validation

#### Pre-Transaction Validation
- **Account Ownership**: Verify client authorization
- **Fraud Prevention**: Anti-money laundering checks
- **Balance Verification**: Sufficient funds check
- **Business Hours**: 24/7 operation with 99.9% availability

#### Refund Validation (MED)
- **90-Day Limit**: From original payment date
- **Remaining Balance**: Cannot exceed original payment minus previous refunds
- **Client Authorization**: Must confirm refund request
- **Fraud Compliance**: Same AML checks as payments

### 6. Data Structures

#### EndToEndId Format
- **Payment**: `E{ISPB}{YYYYMMDD}{HHmm}{11-char-sequence}`
- **Refund**: `D{ISPB}{YYYYMMDD}{HHmm}{11-char-sequence}`
- **Length**: Always 32 characters
- **Uniqueness**: Global identifier across PIX ecosystem

#### Key Gupii Integration Points

##### Service Architecture Recommendations
```ruby
# app/services/jdpi/
├── authentication_service.rb    # Token management & caching
├── dict_service.rb             # PIX key operations  
├── payment_service.rb          # Payment execution
├── refund_service.rb           # MED refund operations
└── webhook_service.rb          # Event notifications
```

##### Models Structure
```ruby
# app/models/
├── pix_key.rb                  # Local PIX key records
├── pix_transaction.rb          # Payment tracking
├── pix_refund.rb              # Refund tracking  
├── jdpi_token.rb              # Token caching
└── jdpi_request_log.rb        # API request audit
```

### 7. Implementation Priority (MED Focus)

#### Phase 1: Core Infrastructure
1. **Authentication Service**: OAuth2 + token caching
2. **HTTP Client**: With idempotency and retry logic
3. **Request Logging**: For compliance and debugging
4. **Error Handling**: Comprehensive error mapping

#### Phase 2: DICT Integration  
1. **PIX Key Query**: Essential for payment validation
2. **Key Management**: Create/update/delete operations
3. **Key Validation**: Format and existence checks

#### Phase 3: Payment Processing
1. **Payment Execution**: Core payment flow
2. **Status Polling**: Async status tracking  
3. **Transaction Queries**: Payment details and history

#### Phase 4: MED Refund System
1. **Refund Request**: Core MED functionality
2. **Refund Status**: Polling and tracking
3. **Refund Validation**: Business rule enforcement
4. **Refund History**: Transaction reconciliation

#### Phase 5: Advanced Features
1. **QR Code Integration**: Dynamic/static QR codes
2. **Webhook Processing**: Real-time notifications
3. **Account Management**: Balance and statement queries
4. **Fraud Integration**: Advanced compliance features

## Key Success Factors

1. **Idempotency**: Absolute requirement for transaction integrity
2. **Status Polling**: Essential for async transaction processing  
3. **Error Recovery**: Robust handling of network/system failures
4. **Compliance**: Strict adherence to Central Bank regulations
5. **Performance**: Efficient token caching and connection pooling
6. **Security**: Proper secret management and audit logging

## Next Steps for Gupii

1. **Environment Setup**: JDPI sandbox credentials and endpoints
2. **Service Implementation**: Start with authentication service
3. **Testing Strategy**: Comprehensive test suite with JDPI sandbox
4. **Monitoring**: Integration with existing observability stack
5. **Documentation**: API integration guides for client applications

---

**Note**: This analysis is based on JDPI API v5.2.1 documentation. Always verify current specifications with JDPI/Central Bank before implementation.
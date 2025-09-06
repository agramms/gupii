# JDPI Integration Roadmap for Gupii

## Phase 1: Foundation Infrastructure (Week 1-2)

### 1.1 Authentication Service
- **File**: `app/services/jdpi/authentication_service.rb`
- **Features**:
  - OAuth 2.0 client credentials flow
  - Redis-based token caching with TTL
  - Automatic token refresh
  - Multi-scope support (dict_api, spi_api, qrcode_api)

### 1.2 HTTP Client Foundation  
- **File**: `lib/jdpi_client.rb`
- **Features**:
  - Faraday-based HTTP client
  - Automatic authentication headers
  - Request/response logging
  - Connection pooling
  - Retry logic with exponential backoff

### 1.3 Idempotency Manager
- **File**: `app/services/jdpi/idempotency_service.rb` 
- **Features**:
  - GUID generation and storage
  - Request deduplication
  - Automatic header injection

### 1.4 Base Models
```ruby
# app/models/jdpi/
├── token.rb              # Token caching model
├── request_log.rb        # API audit log
└── base_response.rb      # Standardized API responses
```

## Phase 2: DICT Integration (Week 3-4)

### 2.1 PIX Key Management Service
- **File**: `app/services/jdpi/dict_service.rb`
- **Endpoints**:
  - Query PIX key: `GET /jdpi/dict/api/v2/consulta/{chave}`
  - Create PIX key: `POST /jdpi/dict/api/v2/chave`
  - Update PIX key: `PUT /jdpi/dict/api/v2/chave/{chave}`
  - Delete PIX key: `DELETE /jdpi/dict/api/v2/chave/{chave}`

### 2.2 PIX Key Models
```ruby
# app/models/
├── pix_key.rb           # Local PIX key storage
├── pix_key_query.rb     # Query results cache
└── pix_account.rb       # Account-key relationships
```

### 2.3 Validation Layer
- **File**: `app/validators/pix_key_validator.rb`
- **Features**:
  - CPF/CNPJ format validation
  - Email format validation  
  - Phone number format validation (+5511999999999)
  - UUID/EVP validation

## Phase 3: Payment Processing (Week 5-6)

### 3.1 Payment Service
- **File**: `app/services/jdpi/payment_service.rb`
- **Endpoints**:
  - Execute payment: `POST /jdpi/spi/api/v2/op`
  - Query payment status: `GET /jdpi/spi/api/v2/op/{idReqJdPi}`
  - Query credit status: `GET /jdpi/spi/api/v2/credito-pagamento/{endToEndId}`

### 3.2 Payment Models
```ruby
# app/models/
├── pix_transaction.rb    # Payment tracking
├── pix_credit.rb        # Credit status tracking
└── payment_status.rb    # Status history
```

### 3.3 Status Polling Service
- **File**: `app/services/jdpi/polling_service.rb`
- **Features**:
  - Async status polling with Solid Queue
  - Exponential backoff for retries
  - Status change notifications
  - Final status persistence

## Phase 4: MED Refund System (Week 7-8)

### 4.1 Refund Service (Core MED)
- **File**: `app/services/jdpi/refund_service.rb`
- **Endpoints**:
  - Request refund: `POST /jdpi/spi/api/v2/od`
  - Query refund status: `GET /jdpi/spi/api/v2/od/{idReqJdPi}`
  - List refund reasons: `GET /jdpi/spi/api/v2/od/motivos`
  - Query refund credit: `GET /jdpi/spi/api/v2/credito-devolucao/{endToEndId}`

### 4.2 MED Models
```ruby
# app/models/
├── pix_refund.rb        # Refund request tracking
├── refund_reason.rb     # MED refund codes (BE08, FR01, MD06, SL02)
└── refund_credit.rb     # Refund credit tracking
```

### 4.3 Business Logic Validation
- **File**: `app/services/jdpi/med_validator.rb`
- **Features**:
  - 90-day refund window validation
  - Remaining balance verification
  - Client authorization checks
  - Fraud compliance validation

## Phase 5: Admin Interface (Week 9-10)

### 5.1 Admin Controllers
```ruby
# app/controllers/admin/
├── pix_keys_controller.rb        # PIX key management
├── transactions_controller.rb    # Payment history
├── refunds_controller.rb         # MED refund management
└── dashboard_controller.rb       # Overview & statistics
```

### 5.2 Admin Views (Using platform2-app-boleto patterns)
```erb
# app/views/admin/
├── pix_keys/
├── transactions/
├── refunds/
└── dashboard/
```

### 5.3 Real-time Updates
- **WebSocket Integration**: For live transaction status
- **Turbo Streams**: For instant UI updates
- **Background Jobs**: Status polling via Solid Queue

## Phase 6: Client API (Week 11-12)

### 6.1 API Controllers
```ruby
# app/controllers/api/v1/
├── events_controller.rb          # Polling endpoint /api/v1/events/poll
├── transactions_controller.rb    # Transaction management
└── refunds_controller.rb        # Refund requests
```

### 6.2 Polling Implementation
- **Endpoint**: `GET /api/v1/events/poll`
- **Features**:
  - Client-specific event filtering
  - Long polling with timeout
  - Event acknowledgment
  - Rate limiting

### 6.3 API Documentation
- **OpenAPI/Swagger** documentation
- **Authentication guides**
- **Integration examples**

## Phase 7: Testing & Quality Assurance (Week 13-14)

### 7.1 Test Suite
```ruby
# spec/
├── services/jdpi/           # Service unit tests
├── models/                  # Model tests
├── controllers/             # Controller integration tests
├── features/                # End-to-end scenarios
└── fixtures/jdpi/           # JDPI response mocks
```

### 7.2 JDPI Sandbox Integration
- **Sandbox Environment**: JDPI testing environment
- **Test Data**: Sample PIX keys, transactions, refunds
- **Automated Testing**: CI/CD integration

### 7.3 Performance Testing
- **Load Testing**: API endpoint performance
- **Memory Testing**: Token caching efficiency
- **Database Testing**: Transaction volume handling

## Phase 8: Monitoring & Observability (Week 15-16)

### 8.1 Grafana Dashboards
- **JDPI API Metrics**: Response times, error rates
- **Transaction Volume**: Payment and refund statistics  
- **Token Management**: Cache hit rates, refresh cycles
- **Error Tracking**: Failed requests, timeout analysis

### 8.2 Alerting
- **Prometheus Rules**: SLA breach alerts
- **Slack Integration**: Real-time notifications
- **PagerDuty**: Critical system alerts

### 8.3 Audit Logging
- **Request/Response Logging**: Complete API audit trail
- **Security Events**: Authentication failures, suspicious activity
- **Compliance Reporting**: Central Bank reporting requirements

## Critical Success Criteria

### ✅ Must-Have Features
1. **OAuth 2.0 Authentication**: Secure JDPI API access
2. **Idempotency**: Transaction integrity guarantee
3. **PIX Key Query**: Essential for payment validation
4. **Payment Execution**: Core payment functionality  
5. **MED Refunds**: BE08, FR01, MD06, SL02 support
6. **Status Polling**: Async transaction tracking
7. **Admin Interface**: PIX key and refund management
8. **API Polling**: Client application integration

### 🎯 Success Metrics
- **API Response Time**: < 2 seconds average
- **Token Cache Hit Rate**: > 95%
- **Transaction Success Rate**: > 99.5%
- **Refund Processing Time**: < 24 hours
- **System Availability**: > 99.9% uptime

### 🚨 Risk Mitigation
1. **JDPI Sandbox**: Comprehensive testing before production
2. **Gradual Rollout**: Phase-by-phase deployment
3. **Rollback Plan**: Quick reversion capability
4. **Documentation**: Detailed integration guides
5. **Support**: 24/7 monitoring during launch

## Dependencies & Prerequisites

### External Dependencies
- **JDPI Credentials**: Client ID, secret, sandbox access
- **Central Bank Certification**: PIX participant status
- **SSL Certificates**: Secure API communication

### Technical Prerequisites  
- **Redis**: Token caching and session management
- **PostgreSQL**: Transaction and audit data storage
- **Solid Queue**: Async job processing
- **Grafana/Prometheus**: Monitoring and alerting

## Delivery Timeline: 16 weeks total

**Weeks 1-4**: Foundation & DICT
**Weeks 5-8**: Payments & MED Refunds  
**Weeks 9-12**: Interfaces & APIs
**Weeks 13-16**: Testing & Launch

This roadmap prioritizes MED (Mecanismo Especial de Devolução) as specified in the project requirements, ensuring comprehensive refund capabilities while building a solid foundation for PIX integration.
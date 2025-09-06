# JDPI Infraction Notification Service Implementation

## Overview

This document provides comprehensive information about the JDPI InfractionNotificationService implementation, including API endpoints, usage patterns, validation rules, and compliance requirements for PIX key infraction management.

## Service Architecture

### Core Service: `Jdpi::InfractionNotificationService`
**Location**: `/app/services/jdpi/infraction_notification_service.rb`

**Authentication Scope Required**: `dict_api` (DICT API operations)

**Base Class**: Inherits from `Jdpi::BaseService` for common JDPI functionality

## Implemented Endpoints

### 1. Include Infraction Notification (8.2.16)
**Endpoint**: `POST /jdpi/dict/api/v2/notificacao-infracao`

**Purpose**: Create a new infraction notification for a PIX key

**Method**: `create_notification(pix_key:, infraction_type:, description:, evidence_data: {})`

**Request Body**:
```json
{
  "chave": "12345678901",
  "key": "12345678901",
  "tipoInfracao": "FRAUD",
  "infractionType": "FRAUD", 
  "descricao": "Suspected fraudulent activity",
  "description": "Suspected fraudulent activity",
  "dadosEvidencia": {
    "suspicious_transactions": 5,
    "risk_score": 0.95
  },
  "evidenceData": {
    "suspicious_transactions": 5,
    "risk_score": 0.95
  },
  "dataHoraNotificacao": "2024-01-01T10:00:00Z",
  "notificationDateTime": "2024-01-01T10:00:00Z",
  "ispb": "12345678",
  "versao": "2.0",
  "version": "2.0"
}
```

**Success Response**: 
```json
{
  "notificationId": "INF123456789",
  "status": "SUBMITTED"
}
```

**Required Headers**: 
- `Authorization: Bearer {access_token}`
- `Chave-Idempotencia: {36-char-guid}` (for idempotency)
- `Content-Type: application/json`

---

### 2. List Processing Infraction Notifications (8.2.17)
**Endpoint**: `GET /jdpi/dict/api/v2/notificacao-infracao/processamento`

**Purpose**: List infraction notifications currently being processed

**Method**: `list_processing_notifications(page_size: 50, page_number: 1)`

**Query Parameters**:
- `tamanhoPagina` / `pageSize`: Number of results per page (1-100, default: 50)
- `numeroPagina` / `pageNumber`: Page number (min: 1, default: 1)

**Success Response**:
```json
{
  "notificacoes": [
    {
      "notificationId": "INF123456789",
      "status": "PROCESSING",
      "chave": "12345678901",
      "tipoInfracao": "FRAUD"
    }
  ],
  "total": 1
}
```

---

### 3. Query Infraction Notification (8.2.18)
**Endpoint**: `GET /jdpi/dict/api/v2/notificacao-infracao/{notificationId}`

**Purpose**: Query details of a specific infraction notification

**Method**: `query_notification(notification_id)`

**Path Parameters**:
- `notificationId`: JDPI notification identifier

**Success Response**:
```json
{
  "notificationId": "INF123456789",
  "status": "PROCESSING",
  "chave": "12345678901", 
  "tipoInfracao": "FRAUD",
  "descricao": "Suspected fraudulent activity",
  "dataHoraNotificacao": "2024-01-01T10:00:00Z",
  "dadosEvidencia": {...}
}
```

---

### 4. Cancel Infraction Notification (8.2.19)
**Endpoint**: `DELETE /jdpi/dict/api/v2/notificacao-infracao/{notificationId}`

**Purpose**: Cancel a submitted or processing infraction notification

**Method**: `cancel_notification(notification_id, reason: nil)`

**Request Body** (optional):
```json
{
  "motivo": "False positive identification",
  "reason": "False positive identification"
}
```

**Success Response**:
```json
{
  "status": "CANCELLED"
}
```

**Required Headers**:
- `Chave-Idempotencia: {36-char-guid}` (for idempotency)

---

### 5. Analyze Infraction Notification (8.2.20)
**Endpoint**: `PUT /jdpi/dict/api/v2/notificacao-infracao/{notificationId}/analise`

**Purpose**: Submit analysis result for an infraction notification

**Method**: `analyze_notification(notification_id, analysis_result:, analysis_notes: nil)`

**Request Body**:
```json
{
  "resultadoAnalise": "APPROVED",
  "analysisResult": "APPROVED",
  "observacoes": "Evidence verified and confirmed",
  "notes": "Evidence verified and confirmed",
  "dataHoraAnalise": "2024-01-01T12:00:00Z",
  "analysisDateTime": "2024-01-01T12:00:00Z",
  "ispbAnalise": "12345678",
  "analystIspb": "12345678"
}
```

**Valid Analysis Results**:
- `APPROVED`: Infraction confirmed and approved
- `REJECTED`: Infraction rejected due to insufficient evidence

**Success Response**:
```json
{
  "status": "APPROVED",
  "analysisResult": "APPROVED"
}
```

**Required Headers**:
- `Chave-Idempotencia: {36-char-guid}` (for idempotency)

---

### 6. List Infraction Notifications (8.2.21)
**Endpoint**: `GET /jdpi/dict/api/v2/notificacao-infracao`

**Purpose**: List infraction notifications with filtering options

**Method**: `list_notifications(page_size: 50, page_number: 1, start_date: nil, end_date: nil, status_filter: nil)`

**Query Parameters**:
- `tamanhoPagina` / `pageSize`: Results per page (1-100)
- `numeroPagina` / `pageNumber`: Page number (min: 1)
- `dataInicio` / `startDate`: Start date filter (YYYY-MM-DD)
- `dataFim` / `endDate`: End date filter (YYYY-MM-DD)
- `situacao` / `status`: Status filter

**Success Response**:
```json
{
  "notificacoes": [
    {
      "notificationId": "INF123456789",
      "status": "APPROVED",
      "chave": "12345678901",
      "tipoInfracao": "FRAUD",
      "dataHoraNotificacao": "2024-01-01T10:00:00Z"
    }
  ],
  "total": 1
}
```

## Infraction Types

### Supported Infraction Types (StatusCodes::InfractionTypes):

1. **FRAUD**: Fraudulent activity detected
2. **AML_VIOLATION**: Anti-money laundering compliance violation
3. **ACCOUNT_MISUSE**: Inappropriate account usage
4. **INVALID_KEY**: PIX key contains invalid information
5. **UNAUTHORIZED_USE**: PIX key used without proper authorization

## Infraction Status Lifecycle

### Status Flow (StatusCodes::InfractionStatus):

1. **SUBMITTED** → Initial state when notification is created
2. **PROCESSING** → JDPI is processing the notification
3. **ANALYZING** → Under manual review/analysis
4. **APPROVED** → Infraction confirmed and approved
5. **REJECTED** → Infraction rejected due to insufficient evidence
6. **CANCELLED** → Notification cancelled before completion
7. **COMPLETED** → Final processing completed

### Status Transitions:
- **Cancellable States**: SUBMITTED, PROCESSING
- **Analyzable States**: SUBMITTED, PROCESSING
- **Final States**: APPROVED, REJECTED, CANCELLED, COMPLETED

## PIX Key Validation

### Supported PIX Key Formats:

1. **CPF**: 11 digits (e.g., "12345678901")
2. **CNPJ**: 14 digits (e.g., "12345678000195")
3. **Email**: Standard email format (e.g., "user@example.com")
4. **Phone**: +55 followed by 10-11 digits (e.g., "+5511999999999")
5. **UUID**: Standard UUID format (e.g., "123e4567-e89b-12d3-a456-426614174000")

### Validation Patterns (StatusCodes::ValidationPatterns):
```ruby
PIX_KEY_CPF = /\A\d{11}\z/
PIX_KEY_CNPJ = /\A\d{14}\z/
PIX_KEY_PHONE = /\A\+55\d{10,11}\z/
PIX_KEY_EMAIL = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/
PIX_KEY_RANDOM = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i
```

## Business Rules & Validation

### Input Validation:

1. **PIX Key**: Required, must match valid format
2. **Infraction Type**: Required, must be valid type from enum
3. **Description**: Required, maximum 500 characters
4. **Evidence Data**: Optional JSON object for supporting evidence

### Operational Rules:

1. **Idempotency**: All mutating operations (CREATE, CANCEL, ANALYZE) require idempotency keys
2. **Authentication**: DICT API scope required for all operations
3. **Pagination**: Maximum 100 results per page for list operations
4. **Status Constraints**: Operations restricted based on current notification status

## Data Models

### Local Storage Models:

#### JdpiInfractionNotification
**Location**: `/app/models/jdpi_infraction_notification.rb`

**Key Attributes**:
- `notification_id`: JDPI notification identifier (unique)
- `pix_key_value`: PIX key value (indexed)
- `infraction_type`: Type of infraction (enum)
- `description`: Infraction description (text)
- `evidence_data`: Supporting evidence (JSON)
- `status`: Current status (enum)
- `jdpi_response`: Latest JDPI API response (JSON)

**Methods**:
- `sync_with_jdpi!`: Synchronize with JDPI API
- `cancel_in_jdpi!(reason)`: Cancel notification in JDPI
- `can_be_cancelled?`: Check if cancellation is allowed
- `can_be_analyzed?`: Check if analysis is allowed
- `masked_pix_key`: Get masked PIX key for display

#### JdpiInfractionLog
**Location**: `/app/models/jdpi_infraction_log.rb`

**Purpose**: Audit trail for all infraction notification operations

**Attributes**:
- `level`: Log level (debug, info, warn, error)
- `message`: Log message
- `metadata`: Additional context (JSON)
- `occurred_at`: Timestamp

## Error Handling

### HTTP Status Codes:
- **200**: Success
- **202**: Accepted (async processing)
- **400**: Bad Request (validation errors)
- **401**: Unauthorized (invalid/expired token)
- **403**: Forbidden (insufficient permissions)
- **404**: Not Found (notification doesn't exist or still processing)
- **409**: Conflict (duplicate or invalid state)
- **500-599**: Server errors

### Common Error Scenarios:
1. **Invalid PIX Key Format**: 400 with validation error
2. **Notification Not Found**: 404 (may indicate still processing)
3. **Cannot Cancel**: 409 due to current status
4. **Authentication Issues**: 401/403 for token problems
5. **Network Issues**: Service handles timeouts and retries

## Security & Compliance

### Authentication:
- **OAuth 2.0 Client Credentials Flow**
- **DICT API Scope Required**: `dict_api`
- **JWT Bearer Token**: All requests must include valid token

### Data Privacy:
- **PIX Key Masking**: Automatic masking in logs and displays
- **Secure Logging**: No sensitive data in plain text logs
- **Audit Trail**: Complete operation history maintained

### Idempotency:
- **36-Character GUID Format**: Required for mutating operations
- **Retry Safety**: Prevents duplicate notifications
- **Request Caching**: Service handles idempotency key generation

## Usage Examples

### Basic Usage:

```ruby
# Initialize service
service = Jdpi::InfractionNotificationService.new

# Create infraction notification
result = service.create_notification(
  pix_key: "12345678901",
  infraction_type: "FRAUD",
  description: "Suspected fraudulent activity",
  evidence_data: { 
    suspicious_transactions: 5,
    risk_score: 0.95 
  }
)

if result
  notification_id = service.notification_id
  puts "Created notification: #{notification_id}"
else
  puts "Errors: #{service.errors.join(', ')}"
end

# Query notification status
status_result = service.query_notification(notification_id)
current_status = status_result["status"] if status_result

# List processing notifications
processing = service.list_processing_notifications(page_size: 20)

# Cancel notification (if allowed)
if service.notification_cancellable?(notification_id)
  cancel_result = service.cancel_notification(
    notification_id, 
    reason: "False positive identification"
  )
end

# Analyze notification (if allowed)
if service.notification_processing?(notification_id)
  analyze_result = service.analyze_notification(
    notification_id,
    analysis_result: "APPROVED",
    analysis_notes: "Evidence verified"
  )
end
```

### Model Integration:

```ruby
# Create notification and store locally
notification = JdpiInfractionNotification.create_from_jdpi_response!(
  pix_key: "12345678901",
  infraction_type: "FRAUD",
  description: "Suspicious activity",
  evidence_data: { risk_score: 0.9 },
  response: service_result
)

# Sync with JDPI
notification.sync_with_jdpi!

# Cancel via model
notification.cancel_in_jdpi!("Investigation completed")

# Check status
puts "Status: #{notification.human_readable_status}"
puts "Type: #{notification.human_readable_type}"
```

## Testing

### Test Suite Location:
- **Service Tests**: `/spec/services/jdpi/infraction_notification_service_spec.rb`
- **Model Tests**: `/spec/models/jdpi_infraction_notification_spec.rb`
- **Shared Context**: `/spec/support/shared_contexts/jdpi_service_setup.rb`
- **Factory**: `/spec/factories/jdpi_infraction_notifications.rb`

### Running Tests:
```bash
# Run all infraction tests
rspec spec/services/jdpi/infraction_notification_service_spec.rb
rspec spec/models/jdpi_infraction_notification_spec.rb

# Run with specific examples
rspec spec/services/jdpi/infraction_notification_service_spec.rb -e "create_notification"
```

## Monitoring & Observability

### Logging:
- **Structured Logging**: All operations logged with context
- **PIX Key Masking**: Sensitive data automatically masked
- **Error Tracking**: Comprehensive error logging and tracking
- **Audit Trail**: Complete history via JdpiInfractionLog model

### Metrics Integration:
- **Prometheus Metrics**: Success/failure rates, response times
- **Grafana Dashboards**: Visual monitoring of infraction operations
- **Distributed Tracing**: Jaeger integration for request tracing

## Configuration

### Required Environment Variables:
```env
JDPI_CLIENT_ID=your_jdpi_client_id
JDPI_CLIENT_SECRET=your_jdpi_client_secret
JDPI_ISPB=your_8_digit_ispb
JDPI_BASE_URL=https://api.jdpi.bcb.gov.br (production)
```

### Rails Credentials (Preferred):
```yaml
# config/credentials.yml.enc
jdpi:
  client_id: your_jdpi_client_id
  client_secret: your_jdpi_client_secret
  ispb: your_8_digit_ispb
  base_url: https://api.jdpi.bcb.gov.br
```

## Integration Checklist

- ✅ Service implementation with all 6 endpoints
- ✅ Local data models for tracking and audit
- ✅ Comprehensive validation and error handling
- ✅ PIX key format validation and masking
- ✅ Status lifecycle management
- ✅ Idempotency support for mutating operations
- ✅ Complete test suite with mocking
- ✅ Internationalization (PT-BR and EN)
- ✅ Documentation and usage examples
- ✅ Security best practices implementation

## Next Steps

1. **Database Migration**: Run migration to create infraction tables
2. **Environment Setup**: Configure JDPI credentials
3. **Testing**: Execute test suite to verify implementation
4. **Admin Interface**: Build web UI for infraction management
5. **API Endpoints**: Create REST API for client applications
6. **Monitoring**: Set up alerts and dashboards for infraction operations

---

**Note**: This implementation follows JDPI API v5.2.1 specifications and Brazilian Central Bank compliance requirements. Always verify current API documentation before deployment.
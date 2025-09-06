# JDPI Integration Usage Examples

## Overview

This document provides practical examples of how to use the JDPI integration services we've implemented for PIX payments, with a focus on MED (Mecanismo Especial de Devolução) refunds.

## Service Architecture

Our implementation follows domain-driven design principles:

```
app/services/jdpi/
├── authentication_service.rb    # OAuth2 + Redis token caching
├── base_service.rb             # Common HTTP client + error handling  
├── idempotency_service.rb      # UUID generation + deduplication
├── med_service.rb              # MED refund operations (BE08, FR01, MD06, SL02)
└── polling_service.rb          # Intelligent status polling

app/jobs/jdpi/
└── polling_job.rb              # Async polling with Solid Queue

config/initializers/
└── jdpi.rb                     # Configuration management
```

## Authentication Examples

### Basic Token Management

```ruby
# Get access token with default scopes
auth_service = Jdpi::AuthenticationService.new
token = auth_service.access_token
# => "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."

# Get token with specific scopes
auth_service = Jdpi::AuthenticationService.new(scopes: ["dict_api", "spi_api"])
token = auth_service.access_token

# Force token refresh
auth_service.refresh_token!
```

### Token Validation

```ruby
# Check if cached token is valid
auth_service = Jdpi::AuthenticationService.new
is_valid = auth_service.token_valid?
# => true/false

# Check specific token validity
cached_token = { access_token: "...", expires_at: 1.hour.from_now }
is_valid = auth_service.token_valid?(cached_token)
```

## MED Refund Examples

### 1. Operational Failure Refund (BE08)

```ruby
# System-initiated refund for operational failures
result = Jdpi::MedService.operational_failure_refund(
  end_to_end_id: "E00038166202312151030abc123def45",
  amount: 150.85,
  reason: "System timeout during transaction processing"
)

if result[:success]
  puts "Refund submitted: #{result[:data]['idReqJdPi']}"
  puts "EndToEndId: #{result[:data]['endToEndIdDevolucao']}"
else
  puts "Refund failed: #{result[:errors].join(', ')}"
end
```

### 2. Fraud Suspicion Refund (FR01)

```ruby
# Enhanced compliance refund for fraud detection
service = Jdpi::MedService.new(
  end_to_end_id_original: "E00038166202312151030xyz789abc12",
  refund_amount: 500.00,
  refund_code: "FR01",
  refund_description: "Suspicious transaction pattern detected",
  fraud_analysis_data: {
    risk_score: 0.85,
    suspicious_patterns: ["velocity", "geolocation"],
    ml_model_version: "1.2.3"
  }
)

result = service.call

# FR01 refunds automatically trigger Central Bank reporting
```

### 3. User-Requested Refund (MD06)

```ruby
# User-initiated refund with client authorization
service = Jdpi::MedService.new(
  end_to_end_id_original: "E00038166202312151030user123req",
  refund_amount: 75.50,
  refund_code: "MD06", 
  refund_description: "Customer requested refund for unsatisfactory service",
  client_authorization_token: "jwt_token_from_client_app",
  client_info: "Customer ID: 12345, Request date: 2023-12-15"
)

result = service.call
```

### 4. PIX Saque/Troco Error Refund (SL02)

```ruby
# Refund for PIX withdrawal/change transaction errors
result = Jdpi::MedService.saque_troco_refund(
  end_to_end_id: "E00038166202312151030saque567troco",
  amount: 20.00,
  reason: "Incorrect change amount dispensed at merchant location"
)
```

## Status Polling Examples

### Synchronous Polling

```ruby
# Poll for refund status with callback
jdpi_request_id = "70F945C1-9024-4123-1001-A1DE2A0000D1"

result = Jdpi::PollingService.poll_sync(
  jdpi_request_id: jdpi_request_id,
  operation_type: "refund",
  max_attempts: 50
) do |status_data, attempt|
  puts "Attempt #{attempt}: Status = #{status_data['stJdPi']}"
  
  # Custom logic - stop polling early if needed
  :continue # or :stop to halt polling
end

if result[:success]
  puts "Final status: #{result[:status_code]}"
  puts "Polling duration: #{result[:duration]}s"
else
  puts "Polling failed: #{result[:errors].join(', ')}"
end
```

### Asynchronous Polling with Solid Queue

```ruby
# Start background polling job
Jdpi::PollingService.start_async_polling(
  jdpi_request_id: "70F945C1-9024-4123-1001-A1DE2A0000D1",
  operation_type: "refund",
  callbacks: {
    on_success: {
      type: 'webhook',
      url: 'https://your-app.com/webhooks/jdpi/success'
    },
    on_error: {
      type: 'email',
      email: { to: 'admin@your-app.com', subject: 'JDPI Refund Failed' }
    }
  }
)
```

### Query Operations

```ruby
# Query refund status directly
result = Jdpi::MedService.query_refund_status(
  jdpi_request_id: "70F945C1-9024-4123-1001-A1DE2A0000D1"
)

# List available refund reasons
reasons = Jdpi::MedService.list_refund_reasons
puts reasons[:data]['resultado'] # Array of refund codes and descriptions

# Query refund credit status
credit_status = Jdpi::MedService.query_refund_credit(
  end_to_end_id: "D00038166202312151051abc123def45"
)
```

## Idempotency Examples

```ruby
# Generate idempotency key
key = Jdpi::IdempotencyService.generate_key
# => "69F963C6-7487-4363-9406-A1DE2A9636D4"

# Store key with context
context = { user_id: 123, operation: "refund", amount: 100.0 }
key = Jdpi::IdempotencyService.create_key(context)

# Check if key exists (for duplicate detection)
exists = Jdpi::IdempotencyService.key_exists?(key)

# Get stored context
stored_context = Jdpi::IdempotencyService.get_context(key)
```

## Error Handling Examples

### Service-Level Error Handling

```ruby
service = Jdpi::MedService.new(
  end_to_end_id_original: "E00038166202312151030test123",
  refund_amount: 100.0,
  refund_code: "MD06"
)

result = service.call

unless result[:success]
  # Handle different error types
  result[:errors].each do |error|
    case error
    when /Validation/
      puts "Input validation error: #{error}"
    when /Auth/
      puts "Authentication error: #{error}"
    when /Network/
      puts "Network connectivity issue: #{error}"
    when /Server error/
      puts "JDPI API error: #{error}"
    else
      puts "Unknown error: #{error}"
    end
  end
end
```

### HTTP-Level Error Handling

```ruby
begin
  result = Jdpi::MedService.operational_failure_refund(
    end_to_end_id: "invalid_format",
    amount: -100 # Invalid amount
  )
rescue ActiveModel::ValidationError => e
  puts "Validation failed: #{e.message}"
rescue Faraday::TimeoutError => e
  puts "Request timed out: #{e.message}"
rescue Redis::BaseError => e
  puts "Redis connection error: #{e.message}"
end
```

## Configuration Examples

### Rails Credentials (Recommended)

```yaml
# config/credentials.yml.enc
jdpi:
  client_id: "your_client_id"
  client_secret: "your_client_secret"  
  ispb: "12345678"
  base_url: "https://api-sandbox.jdpi.bcb.gov.br"

redis:
  url: "redis://redis123@redis:6379/0"
```

### Environment Variables (Alternative)

```bash
# .env or environment
JDPI_CLIENT_ID=your_client_id
JDPI_CLIENT_SECRET=your_client_secret
JDPI_ISPB=12345678
JDPI_BASE_URL=https://api-sandbox.jdpi.bcb.gov.br
REDIS_URL=redis://redis123@redis:6379/0
```

### Runtime Configuration

```ruby
# Modify configuration at runtime
Jdpi.configure do |config|
  config.base_url = 'https://api-production.jdpi.bcb.gov.br'
  config.timeout = 120
end
```

## Testing Examples

### Service Testing with RSpec

```ruby
RSpec.describe Jdpi::MedService do
  describe '#call' do
    let(:service) do
      described_class.new(
        end_to_end_id_original: 'E00038166202312151030test123',
        refund_amount: 100.0,
        refund_code: 'BE08',
        refund_description: 'Test refund'
      )
    end

    before do
      # Mock JDPI API response
      allow_any_instance_of(Faraday::Connection).to receive(:post)
        .and_return(double(status: 202, body: { 'idReqJdPi' => 'test-id' }))
    end

    it 'successfully processes refund' do
      result = service.call
      
      expect(result[:success]).to be true
      expect(result[:data]['idReqJdPi']).to eq('test-id')
    end
  end
end
```

### Integration Testing

```ruby
# spec/integration/jdpi_integration_spec.rb
RSpec.describe 'JDPI Integration', type: :integration do
  it 'processes complete refund workflow' do
    # 1. Submit refund
    refund_result = Jdpi::MedService.operational_failure_refund(
      end_to_end_id: 'E00038166202312151030integration',
      amount: 50.0
    )
    
    expect(refund_result[:success]).to be true
    jdpi_request_id = refund_result[:data]['idReqJdPi']
    
    # 2. Poll for status
    polling_result = Jdpi::PollingService.poll_sync(
      jdpi_request_id: jdpi_request_id,
      operation_type: 'refund',
      max_attempts: 10
    )
    
    expect(polling_result[:success]).to be true
  end
end
```

## Production Considerations

### Performance Optimization

```ruby
# Use connection pooling for high-volume operations
Faraday.default_connection_options = {
  pool_size: 25,
  pool_timeout: 30
}

# Batch multiple operations
refunds = [
  { end_to_end_id: "E123...", amount: 100 },
  { end_to_end_id: "E456...", amount: 200 }
]

results = refunds.map do |refund_data|
  Jdpi::MedService.operational_failure_refund(**refund_data)
end
```

### Monitoring Integration

```ruby
# Custom metrics for Prometheus/Grafana
class JdpiMetrics
  def self.record_refund_request(code:, amount:, success:)
    # Increment counters
    # Record histograms
    # Track error rates
  end
end

# In your service calls
result = Jdpi::MedService.operational_failure_refund(params)
JdpiMetrics.record_refund_request(
  code: 'BE08',
  amount: params[:amount],
  success: result[:success]
)
```

This implementation provides a robust, compliant, and scalable foundation for PIX payment integration through JDPI, with particular strength in MED refund processing as required by your project specifications.
# Observability Stack Setup Guide

Complete guide for MinIO, StatsD/Graphite, and Jaeger integration in the Gupii development environment.

## 🎯 Overview

The observability stack provides comprehensive monitoring and storage solutions:

- **MinIO**: S3-compatible object storage for Active Storage
- **StatsD/Graphite**: Metrics collection and visualization
- **Jaeger**: Distributed tracing for API calls and requests
- **Existing**: Prometheus + Grafana for infrastructure metrics

## 🚀 Quick Start

### 1. Install Dependencies

```bash
# Install new Ruby gems
bundle install

# Verify configuration
bin/verify_observability_stack
```

### 2. Start Services

```bash
# Essential services only (PostgreSQL, Redis, MinIO)
docker-compose up -d

# Full observability stack (includes monitoring tools)
docker-compose --profile tools up -d

# With domain support (nginx reverse proxy)
docker-compose --profile tools --profile domains up -d
```

### 3. Start Development Environment

#### Option A: Foreman (Recommended)
```bash
# Start all development processes (Rails + Workers + CSS)
foreman start -f Procfile.dev
```

This automatically starts:
- Rails application server (port 3000)
- Solid Queue worker (single worker for all background jobs)
- Tailwind CSS watcher (auto-rebuild styles)

#### Option B: Manual Process Management
```bash
# Terminal 1: Rails server
bin/rails server

# Terminal 2: Background workers
bin/rails solid_queue:start

# Terminal 3: CSS watcher
bin/rails tailwindcss:watch
```

### 4. Access Web Interfaces

All services are available via secure *.gupii.local domains:

| Service | URL | Credentials |
|---------|-----|-------------|
| **Rails App** | https://gupii.local | N/A |
| **MinIO Console** | https://minio-console.gupii.local | minioadmin / minioadmin123 |
| **Graphite** | https://graphite.gupii.local | N/A |
| **Jaeger** | https://jaeger.gupii.local | N/A |
| **Grafana** | https://grafana.gupii.local | admin / admin123 |
| **Prometheus** | https://prometheus.gupii.local | N/A |

## 📊 MinIO Configuration

### Rails Active Storage

Active Storage is configured to use MinIO in development:

```yaml
# config/storage.yml
minio:
  service: S3
  access_key_id: minioadmin
  secret_access_key: minioadmin123
  endpoint: https://minio.gupii.local
  bucket: gupii-development
  force_path_style: true
```

### Testing File Uploads

```ruby
# Rails console test
rails console

# Create a test file upload
file = Rails.root.join("README.md")
blob = ActiveStorage::Blob.create_and_upload!(
  io: File.open(file),
  filename: "test-upload.md",
  content_type: "text/markdown"
)

puts "File uploaded: #{blob.key}"
puts "URL: #{blob.url}"
```

### MinIO Bucket Management

```bash
# Access MinIO console at https://minio-console.gupii.local
# Default credentials: minioadmin / minioadmin123

# Create buckets for different environments
# gupii-development (auto-created)
# gupii-test
# gupii-production
```

## 📈 StatsD/Graphite Integration

### Automatic Metrics Collection

The `PspMetricsService` automatically sends metrics to StatsD:

```ruby
# Metrics are automatically sent when called
PspMetricsService.automated_collection

# Manual metrics collection
service = PspMetricsService.new
service.collect_all_metrics
```

### Custom Metrics

```ruby
# Send custom metrics from anywhere in the application
StatsD.increment("gupii.user.login")
StatsD.gauge("gupii.psp.count", PaymentServiceProvider.count)
StatsD.timing("gupii.api.response_time", 125)
```

### Viewing Metrics

1. Access Graphite at https://graphite.gupii.local
2. Navigate to the "Composer" tab
3. Browse metrics under `gupii.*` namespace
4. Create graphs and dashboards

### Grafana Integration

Add Graphite as a data source in Grafana:

1. Go to https://grafana.gupii.local
2. Login: admin / admin123
3. Add Data Source → Graphite
4. URL: `http://graphite:80`
5. Create dashboards with PSP metrics

## 🔍 Jaeger Distributed Tracing

### Automatic Instrumentation

OpenTelemetry automatically instruments:

- Rails requests and responses
- Active Record database queries
- Redis operations
- Faraday HTTP client calls (JDPI API)
- Background jobs

### Manual Tracing

```ruby
# Add custom spans in services
tracer = Rails.application.config.otel_tracer

tracer.in_span("jdpi_api_call") do |span, context|
  span.set_attribute("api.endpoint", "/some/endpoint")
  span.set_attribute("api.method", "POST")

  # Your API call code here
  result = some_api_call

  span.set_attribute("api.response.status", result.status)
end
```

### Viewing Traces

1. Access Jaeger at https://jaeger.gupii.local
2. Select service: "gupii"
3. Search for traces by operation or time range
4. Click on traces to see detailed timing information

### JDPI API Tracing

All JDPI API calls are automatically traced with:
- Request/response timing
- HTTP status codes
- Request/response payloads (sanitized)
- Error details

## ⚙️ Configuration

### Environment Variables

```bash
# MinIO Configuration
MINIO_ENDPOINT=https://minio.gupii.local
MINIO_ACCESS_KEY_ID=minioadmin
MINIO_SECRET_ACCESS_KEY=minioadmin123
MINIO_BUCKET=gupii-development

# StatsD Configuration
STATSD_HOST=localhost
STATSD_PORT=8125
STATSD_NAMESPACE=gupii

# OpenTelemetry Configuration
OTEL_SERVICE_NAME=gupii
OTEL_SERVICE_VERSION=1.0.0
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
OTEL_SAMPLE_RATE=1.0
```

### Rails Credentials

```yaml
# config/credentials.yml.enc (use rails credentials:edit)
minio:
  access_key_id: your_minio_key
  secret_access_key: your_minio_secret
  endpoint: https://minio.gupii.local

statsd:
  host: localhost
  namespace: gupii

otel:
  service:
    name: gupii
  exporter:
    otlp:
      endpoint: http://localhost:4318
```

## 🔧 Troubleshooting

### Common Issues

**MinIO Connection Errors**
```bash
# Check MinIO service status
docker-compose ps minio

# View MinIO logs
docker-compose logs minio

# Test connectivity
curl -k https://minio.gupii.local/minio/health/live
```

**StatsD Metrics Not Appearing**
```bash
# Check Graphite service
docker-compose ps graphite

# View StatsD logs
docker-compose logs graphite

# Test StatsD connection
echo "test.metric:1|c" | nc -u localhost 8125
```

**Jaeger Traces Missing**
```bash
# Check Jaeger service
docker-compose ps jaeger

# View Jaeger logs
docker-compose logs jaeger

# Check OpenTelemetry configuration
rails console
Rails.application.config.otel_tracer.class
```

### Verification Script

Run the comprehensive verification script:

```bash
bin/verify_observability_stack
```

This script tests:
- AppConfig integration
- StatsD connection
- OpenTelemetry tracing
- Active Storage MinIO configuration
- PspMetricsService integration

### Performance Considerations

**Development Environment**
- 100% trace sampling (all requests traced)
- Verbose logging enabled
- All instrumentation active

**Production Environment**
- Configurable sample rate (default 10%)
- Error-only logging
- Selective instrumentation

## 📚 Additional Resources

- [MinIO Documentation](https://docs.min.io/)
- [StatsD/Graphite Documentation](https://graphite.readthedocs.io/)
- [Jaeger Documentation](https://www.jaegertracing.io/docs/)
- [OpenTelemetry Ruby Documentation](https://opentelemetry.io/docs/instrumentation/ruby/)
- [Rails Active Storage Guide](https://guides.rubyonrails.org/active_storage_overview.html)

## 🎯 Success Criteria

✅ **MinIO**: File uploads work via Rails console
✅ **StatsD**: Metrics appear in Graphite dashboard
✅ **Jaeger**: Request traces visible in UI
✅ **Integration**: All services accessible via *.gupii.local domains
✅ **Performance**: Minimal overhead in development environment
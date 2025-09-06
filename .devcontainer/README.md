# Gupii Development Environment

A comprehensive Rails development environment with DevOps tooling and infrastructure services.

## 🏗️ Architecture

This development environment provides:

- **Application Stack**: Rails 7+ with PostgreSQL and Redis
- **Monitoring**: Prometheus, Grafana, StatsD/Graphite
- **Development Tools**: pgAdmin, MailHog, MinIO
- **Observability**: Jaeger distributed tracing
- **Proxy**: Nginx reverse proxy

## 🚀 Services

### Core Infrastructure
- **Rails App** (Port 3000): Main application server
- **PostgreSQL** (Port 5432): Primary database
- **Redis** (Port 6379): Caching, sessions, background jobs

### Database Management
- **pgAdmin** (Port 5050): PostgreSQL web interface
  - Email: `admin@gupii.dev`
  - Password: `admin123`

### Monitoring & Metrics
- **Prometheus** (Port 9090): Metrics collection
- **Grafana** (Port 3001): Dashboards and visualization
  - Username: `admin`
  - Password: `admin123`
- **StatsD/Graphite** (Port 8080): Metrics aggregation

### Development Tools
- **MailHog** (Port 8025): Email testing interface
- **MinIO** (Port 9000/9001): S3-compatible object storage
  - Access Key: `minioadmin`
  - Secret Key: `minioadmin123`
- **Jaeger** (Port 16686): Distributed tracing UI

### Reverse Proxy
- **Nginx** (Port 80): Unified access point
  - `/` → Rails app
  - `/grafana/` → Grafana
  - `/prometheus/` → Prometheus
  - `/pgadmin/` → pgAdmin
  - `/mail/` → MailHog
  - `/minio/` → MinIO Console
  - `/jaeger/` → Jaeger UI

## 📱 Quick Access URLs

When the devcontainer is running:

- Rails App: http://localhost:3000
- pgAdmin: http://localhost:5050
- Grafana: http://localhost:3001
- Prometheus: http://localhost:9090
- MailHog: http://localhost:8025
- MinIO Console: http://localhost:9001
- Jaeger: http://localhost:16686
- Unified Proxy: http://localhost

## 🔧 Environment Variables

The application container includes:

```env
DATABASE_URL=postgresql://postgres:postgres@postgres:5432/gupii_development
REDIS_URL=redis://redis123@redis:6379/0
RAILS_ENV=development
```

## 🛠️ Development Workflow

1. **Start Environment**: Open in VS Code with Dev Containers extension
2. **Database Setup**: Rails will auto-create with PostgreSQL + Tailwind
3. **Monitor**: Use Grafana for metrics, pgAdmin for database management
4. **Email Testing**: Configure Rails to use MailHog SMTP (localhost:1025)
5. **File Storage**: Use MinIO for S3-compatible storage testing

## 📊 Monitoring Setup

### Rails Application Metrics
Add to your Rails app for Prometheus integration:

```ruby
# Gemfile
gem 'prometheus-client'

# config/routes.rb
get '/metrics', to: 'metrics#show'
```

### StatsD Integration
```ruby
# Gemfile
gem 'statsd-ruby'

# Usage
statsd = Statsd.new('statsd', 8125)
statsd.increment('gupii.user.login')
```

## 🔒 Security Notes

- All default passwords are for development only
- Services are not exposed externally in production
- Use proper secrets management in production environments

## 🎯 Best Practices

1. **Database**: Use migrations and seeds for consistent development data
2. **Caching**: Leverage Redis for improved performance testing
3. **Monitoring**: Set up custom Grafana dashboards for your metrics
4. **Email**: Test email flows with MailHog before production
5. **Storage**: Use MinIO to test S3 integrations locally

## 🚀 Getting Started

1. Ensure Docker and VS Code with Dev Containers extension are installed
2. Open this project in VS Code
3. Click "Reopen in Container" when prompted
4. Wait for all services to start (check ports panel)
5. Access services via the URLs above

Happy coding! 🎉
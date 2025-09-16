# Gupii Development Environment

A comprehensive Rails 8 development environment with domain-based routing, HTTPS support, and complete observability stack.

## 🏗️ Architecture

This development environment provides:

- **Application Stack**: Rails 8.0.2.1 with Ruby 3.4.5, PostgreSQL 16, Redis 7
- **Domain Architecture**: Production-like *.gupii.local domains with HTTPS
- **Monitoring**: Prometheus, Grafana, StatsD/Graphite
- **Development Tools**: pgAdmin, MailHog, MinIO
- **Observability**: Jaeger distributed tracing
- **Reverse Proxy**: Nginx with SSL termination and domain routing
- **Automation**: Team onboarding scripts and environment detection

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

### Domain-Based Routing
- **Nginx** (Ports 80/443): HTTPS-first domain routing
  - `https://gupii.local` → Rails app
  - `https://grafana.gupii.local` → Grafana
  - `https://prometheus.gupii.local` → Prometheus
  - `https://pgadmin.gupii.local` → pgAdmin
  - `https://mail.gupii.local` → MailHog
  - `https://minio.gupii.local` → MinIO Console
  - `https://jaeger.gupii.local` → Jaeger UI
- **SSL Certificates**: Auto-generated wildcard certificates for *.gupii.local

## 📱 Quick Access URLs

### Primary Access (Domain-based HTTPS)
- **Rails App**: https://gupii.local
- **Grafana**: https://grafana.gupii.local (admin/admin123)
- **Prometheus**: https://prometheus.gupii.local
- **pgAdmin**: https://pgadmin.gupii.local (admin@gupii.dev/admin123)
- **MailHog**: https://mail.gupii.local
- **MinIO Console**: https://minio.gupii.local (minioadmin/minioadmin123)
- **Jaeger**: https://jaeger.gupii.local

### Direct Port Access (Bypass nginx)
- Rails App: http://localhost:3000
- pgAdmin: http://localhost:5050
- Grafana: http://localhost:3001
- Prometheus: http://localhost:9090
- MailHog: http://localhost:8025
- MinIO Console: http://localhost:9001
- Jaeger: http://localhost:16686

### Setup Requirements
**Automatic Setup** (Recommended):
```bash
.devcontainer/scripts/setup-environment.sh
```

**Manual Setup**:
Add to `/etc/hosts`:
```
127.0.0.1 gupii.local grafana.gupii.local prometheus.gupii.local pgadmin.gupii.local mail.gupii.local minio.gupii.local jaeger.gupii.local
```

## 🔧 Environment Variables

The application container includes:

```env
DATABASE_URL=postgresql://postgres:postgres@postgres:5432/gupii_development
REDIS_URL=redis://redis123@redis:6379/0
RAILS_ENV=development
```

## 🛠️ Development Workflow

1. **Environment Setup**: Open in VS Code with Dev Containers extension
2. **Domain Configuration**: Run setup scripts or manually configure /etc/hosts
3. **Access Application**: Navigate to https://gupii.local (accept SSL warnings)
4. **Development**: Use domain-based URLs for all services
5. **Monitoring**: Grafana dashboards at https://grafana.gupii.local
6. **Database Management**: pgAdmin at https://pgadmin.gupii.local
7. **Email Testing**: MailHog at https://mail.gupii.local
8. **File Storage**: MinIO console at https://minio.gupii.local

### First-Time Setup
1. DevContainer automatically runs environment detection
2. SSL certificates are generated for *.gupii.local
3. Domain configuration is validated
4. Services start with production-like URLs

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

### For New Team Members
1. **Prerequisites**: Docker Desktop + VS Code with Dev Containers extension
2. **Clone & Open**: Clone repository and open in VS Code
3. **DevContainer**: Click "Reopen in Container" when prompted
4. **Automated Setup**: Environment detection and domain setup runs automatically
5. **Access**: Navigate to https://gupii.local (accept SSL certificate)
6. **Team Onboarding**: All domains and certificates configured automatically

### For GitHub Codespaces
- Domain setup is automatically bypassed
- Port forwarding used instead of local domains
- All services accessible via VS Code ports panel

### Environment Detection
The DevContainer automatically detects:
- **Local Development**: Full domain setup with SSL certificates
- **GitHub Codespaces**: Port-based access with forwarding
- **CI Environment**: Minimal setup for testing

Happy coding! 🎉
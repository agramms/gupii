# Gupii 🐹

[![CI](https://github.com/agramms/gupii/workflows/Gupii%20PIX%20Integration%20CI/badge.svg)](https://github.com/agramms/gupii/actions)
[![Code Climate](https://img.shields.io/codeclimate/maintainability/agramms/gupii.svg)](https://codeclimate.com/github/agramms/gupii)
[![Code Coverage](https://img.shields.io/codeclimate/coverage/agramms/gupii.svg)](https://codeclimate.com/github/agramms/gupii)
[![codecov](https://codecov.io/gh/agramms/gupii/branch/main/graph/badge.svg)](https://codecov.io/gh/agramms/gupii)
[![Ruby Version](https://img.shields.io/badge/ruby-3.4.5-red.svg)](https://www.ruby-lang.org/)
[![Rails Version](https://img.shields.io/badge/rails-8.0.2-red.svg)](https://rubyonrails.org/)

**PIX Payment Integration System for the Brazilian Central Bank**

Gupii is a Rails 8 application that provides seamless integration with Brazil's PIX instant payment system through the JDPI (Diretório de Identificadores de Contas Transacionais) API.

![Gupii Mascot](tmp/gupii.png)

## 🚀 Features

- **PIX Key Management** - Create and manage PIX keys for instant payments
- **MED Integration** - Mecanismo Especial de Devolução (Special Refund Mechanism)
- **Infraction Reports** - Handle PIX transaction disputes and violations
- **Transaction Refunds** - Process refunds through the Central Bank system
- **Fraud Marking System** - Mark and track fraudulent PIX transactions
- **Disputes Management** - Complete dispute lifecycle with 6-day customer response SLA
- **SPI Transaction Lookup** - Real-time PIX transaction consultation via JDPI API
- **Admin Dashboard** - Beautiful Tailwind CSS interface with professional UX
- **Client API** - RESTful API with polling for external applications
- **Multi-Database** - Separate databases for app, cache, and job queue
- **Full Observability** - Comprehensive monitoring with Grafana, Prometheus, and Jaeger

## 🏗️ Architecture

- **Rails 8.0.2.1** with Ruby 3.4.5 (Latest stable with YJIT + PRISM)
- **PostgreSQL** multi-database setup (main, cache, queue, cable)
- **Solid Cache, Solid Queue & Solid Cable** - Database-backed Rails infrastructure
- **iugu Identity Provider** authentication (OAuth2 + JWT with JWKS validation)
- **JDPI API** integration for Central Bank compliance
- **Tailwind CSS 4.x** responsive admin interface with professional components
- **Docker** containerized deployment with comprehensive DevContainer setup
- **Nginx** reverse proxy with smart routing and subpath support

## 🛠️ Development Setup

### Prerequisites

**Option A: DevContainer (Recommended)**
- Docker Desktop
- VS Code with Dev Containers extension

**Option B: Local Development**
- Ruby 3.4.5
- PostgreSQL 16+
- Redis 7+
- Node.js (for Tailwind CSS compilation)

### Quick Start with DevContainers

1. **Clone and open in VS Code**
   ```bash
   git clone https://github.com/your-org/gupii.git
   cd gupii
   code .
   ```

2. **Reopen in Container**
   - VS Code will prompt to "Reopen in Container"
   - Or use Command Palette: `Dev Containers: Reopen in Container`

3. **Wait for DevContainer setup** (first time takes 2-3 minutes)
   - Automatic Ruby, PostgreSQL, Redis, and all tools installation
   - Gems and dependencies automatically installed

4. **Start the development environment**
   ```bash
   bin/dev
   ```

5. **Access the application**
   - **Rails App**: http://localhost/app (with nginx proxy)
   - **Direct Access**: http://localhost:3000 (Rails server only)
   - **API Health**: http://localhost/app/api/v1/health

### DevContainer Services

The development environment includes a complete observability stack:

- **Rails App**: http://localhost/app (main application)
- **Grafana**: http://localhost/grafana (dashboards - admin/admin123)  
- **Prometheus**: http://localhost/prometheus (metrics)
- **pgAdmin**: http://localhost/pgadmin (database - admin@gupii.dev/admin123)
- **MailHog**: http://localhost/mail (email testing)
- **MinIO Console**: http://localhost/minio (S3 storage - minioadmin/minioadmin123)
- **Jaeger**: http://localhost/jaeger (distributed tracing)

### Local Development Setup

1. **Install Ruby and dependencies**
   ```bash
   # Using rbenv
   rbenv install 3.4.5
   rbenv global 3.4.5
   
   # Install bundler
   gem install bundler
   
   # Install gems
   bundle install
   ```

2. **Setup PostgreSQL**
   ```bash
   # macOS with Homebrew
   brew install postgresql@16
   brew services start postgresql@16
   
   # Create databases
   bin/rails db:create:all
   bin/rails db:migrate:all
   ```

3. **Setup Redis**
   ```bash
   # macOS with Homebrew  
   brew install redis
   brew services start redis
   ```

4. **Start development server**
   ```bash
   # Start both Rails server and Tailwind watcher
   bin/dev
   
   # Or start individually:
   bin/rails server
   bin/rails tailwindcss:watch
   ```

### Development Workflow

1. **Start services**
   ```bash
   bin/dev  # Starts Rails server + Tailwind CSS watcher
   ```

2. **Run tests**
   ```bash
   # Validation script for subpath URL generation  
   bin/rails runner script/validate_subpath_urls.rb
   
   # Unit tests (when test environment is configured)
   bin/rails test
   ```

3. **Code quality**
   ```bash
   bundle exec rubocop              # Ruby style checks
   bundle exec brakeman            # Security analysis  
   bin/rails runner script/validate_subpath_urls.rb  # URL validation
   ```

4. **Database operations**
   ```bash
   bin/rails db:migrate:all        # Run migrations on all databases
   bin/rails db:rollback:all       # Rollback migrations on all databases
   bin/rails db:reset:all          # Reset all databases
   ```

## 🧪 Testing

```bash
# URL generation validation (custom test)
bin/rails runner script/validate_subpath_urls.rb

# Run all tests (when test environment is configured)
bin/rails test

# Run security scans
bundle exec brakeman

# Code style and formatting
bundle exec rubocop
bundle exec rubocop --auto-correct  # Auto-fix issues
```

## 💎 Gems & Dependencies

### Core Framework

- **`rails (~> 8.0.2)`** - Latest Rails with enhanced performance, modern asset pipeline, and improved developer experience
- **`pg (~> 1.1)`** - PostgreSQL adapter for multi-database architecture (main, cache, queue, cable)
- **`puma (>= 5.0)`** - High-performance web server with HTTP/2 support and clustering
- **`bootsnap`** - Faster boot times through Ruby bytecode caching

### Modern Rails Infrastructure  

- **`solid_cache`** - Database-backed Rails.cache implementation (replaces Redis for caching)
- **`solid_queue`** - Database-backed Active Job adapter with reliability and performance
- **`solid_cable`** - Database-backed Action Cable adapter for WebSocket connections
- **`thruster`** - HTTP asset caching, compression, and X-Sendfile acceleration for Puma

### Frontend & Assets

- **`propshaft`** - Modern asset pipeline replacement for Sprockets, faster and simpler
- **`importmap-rails`** - ES6 modules with import maps, no bundling required
- **`turbo-rails`** - Hotwire SPA-like navigation and forms without JavaScript frameworks  
- **`stimulus-rails`** - Modest JavaScript framework for progressive enhancement
- **`tailwindcss-rails`** - Utility-first CSS framework with live recompilation

### Authentication & API Integration

- **`jwt (~> 2.8)`** - JSON Web Token implementation for iugu Identity Provider integration
- **`oauth2 (~> 2.0)`** - OAuth 2.0 client for secure authentication flows
- **`faraday (~> 2.8)`** - HTTP client library for JDPI API integration with middleware support

### Data & Performance

- **`redis (~> 5.0)`** - Additional caching layer and session storage
- **`pagy (~> 6.2)`** - Fast, efficient pagination with minimal memory footprint
- **`ransack (~> 4.1)`** - Advanced search and filtering capabilities
- **`hashids (~> 1.0)`** - Generate short, URL-safe unique identifiers (used for dispute/notification IDs)
- **`jbuilder`** - JSON API response building with clean, declarative syntax

### Monitoring & Observability

- **`prometheus-client (~> 4.0)`** - Metrics collection and monitoring integration  
- **`prometheus-client-mmap (~> 1.0)`** - Memory-mapped metrics for better performance in production

### Development & Testing

- **`debug`** - Modern debugging interface (replaces byebug in Rails 7+)
- **`web-console`** - Interactive console on error pages for faster debugging
- **`pry (~> 0.14)` & `pry-byebug (~> 3.10)`** - Enhanced REPL and debugging tools

### Code Quality & Security

- **`brakeman`** - Static security vulnerability scanner for Rails applications
- **`rubocop-rails-omakase`** - Opinionated Ruby style guide following Rails conventions

### Testing

- **`capybara`** - Integration testing framework for web applications
- **`selenium-webdriver`** - Browser automation for system tests
- **`mocha (~> 2.1)`** - Mocking and stubbing library for isolated unit tests
- **`ostruct`** - Ruby 3.4+ compatibility for legacy code structures

### Why These Gems?

**Performance Focus**: Solid* gems provide database-backed infrastructure that's easier to manage than Redis/Sidekiq in development and can scale better in production with proper database optimization.

**Modern Rails**: Rails 8 focuses on simplicity - importmap eliminates complex JavaScript bundling, Turbo provides SPA-like experience without heavy frontend frameworks.

**Financial Compliance**: JWT and OAuth2 provide enterprise-grade authentication required for Central Bank integrations. Faraday offers robust HTTP client capabilities for API reliability.

**Developer Experience**: The combination of debugging tools (debug, pry, web-console) with code quality tools (rubocop, brakeman) ensures both productivity and security.

**Observability**: Prometheus integration provides production-ready metrics collection essential for financial applications that require monitoring and alerting.

## 🚢 Deployment & CI/CD

Gupii uses **GitHub Actions** for comprehensive CI/CD:

### CI Pipeline Features
- **Automated Testing**: Unit tests, system tests, and custom validation scripts
- **Security Scanning**: Brakeman for Ruby vulnerabilities, ImportMap audit for JS dependencies
- **Code Quality**: RuboCop linting with Rails Omakase style guide + Code Climate analysis
- **Code Coverage**: SimpleCov with Code Climate and Codecov integration
- **Docker Builds**: Automated container builds with caching
- **Multi-Environment**: Supports staging and production deployments

### CI Services Setup

To enable the badges and integrate with external services:

1. **Code Climate Setup**:
   ```bash
   # 1. Sign up at https://codeclimate.com
   # 2. Connect your GitHub repository
   # 3. Add QLTY_COVERAGE_TOKEN secret to GitHub repository
   # 4. Coverage and quality metrics automatically uploaded by CI
   ```

2. **Codecov Setup**:
   ```bash
   # 1. Sign up at https://codecov.io
   # 2. Install GitHub app for your repository
   # 3. Coverage automatically uploaded by CI
   # 4. Badges automatically work with repository path
   ```

3. **Configuration Files**:
   - `.simplecov` - Ruby code coverage configuration with LCOV output
   - `.github/workflows/ci.yml` - GitHub Actions workflow with Code Climate integration

### CI Triggers
- **Pull Requests**: Full test suite with coverage reporting
- **Main/Develop Branch**: Complete CI pipeline with artifact uploads
- **Manual Trigger**: `workflow_dispatch` for on-demand runs

## 📡 API Usage

### Health Check
```bash
# With nginx proxy (DevContainer)
curl http://localhost/app/api/v1/health

# Direct access
curl http://localhost:3000/api/v1/health
```

### Polling for Updates
```bash
# PIX operations polling
curl http://localhost/app/api/v1/events/poll

# Disputes polling  
curl http://localhost/app/api/v1/disputes/stats

# Fraud markings polling
curl http://localhost/app/api/v1/fraud_markings/stats
```

### PIX Operations API
```bash
# List PIX operations
curl http://localhost/app/api/v1/pix_operations

# Create PIX operation
curl -X POST http://localhost/app/api/v1/pix_operations \
  -H "Content-Type: application/json" \
  -d '{"amount": 100.00, "recipient_key": "user@example.com"}'
```

### Payment Service Providers API
```bash
# List active PSPs
curl http://localhost/app/api/v1/payment_service_providers/active

# Search PSPs by ISPB
curl http://localhost/app/api/v1/payment_service_providers/by_ispb/12345678
```

## 🔧 Configuration

### Environment Variables

```env
# Database URLs (multi-database architecture)
DATABASE_URL=postgresql://user:pass@host:5432/gupii_production
SOLID_CACHE_DATABASE_URL=postgresql://user:pass@host:5432/gupii_cache_production  
SOLID_QUEUE_DATABASE_URL=postgresql://user:pass@host:5432/gupii_queue_production
SOLID_CABLE_DATABASE_URL=postgresql://user:pass@host:5432/gupii_cable_production

# Redis (additional caching layer)
REDIS_URL=redis://user:pass@host:6379/0

# Authentication (iugu Identity Provider)
IUGU_IDENTITY_CLIENT_ID=your_client_id
IUGU_IDENTITY_CLIENT_SECRET=your_client_secret
IUGU_IDENTITY_BASE_URL=https://identity.iugu.com

# JDPI API (Central Bank PIX integration)
JDPI_BASE_URL=https://api.jdpi.bcb.gov.br
JDPI_CLIENT_ID=your_jdpi_client_id
JDPI_CLIENT_SECRET=your_jdpi_client_secret

# Application URLs (for OAuth callbacks)
APP_HOST=your-domain.com
APP_PROTOCOL=https
```

### Rails Credentials

Use `rails credentials:edit` to store sensitive information:

```yaml
# config/credentials.yml.enc (encrypted)
oauth:
  client_id: your_iugu_oauth_client_id
  client_secret: your_iugu_oauth_client_secret

core:
  api_token: your_core_api_token

# JDPI credentials
jdpi:
  client_id: your_jdpi_client_id
  client_secret: your_jdpi_client_secret
  
# Test environment credentials  
test:
  oauth:
    client_id: test_client_id
    client_secret: test_client_secret
```

### Development-Specific Configuration

In development, the application runs with subpath routing:

- **Nginx Proxy**: Routes requests intelligently based on path
- **Rails Subpath**: Configured to run under `/app` prefix  
- **URL Generation**: Automatic subpath-aware URL helpers
- **OAuth Callbacks**: Properly configured for subpath environment

This allows multiple services to run simultaneously:
- Rails app at `/app`
- Grafana at `/grafana`  
- MinIO at `/minio`
- pgAdmin at `/pgadmin`
- And more...

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📚 Documentation

- **Technical Guide**: See [CLAUDE.md](CLAUDE.md) for detailed architecture
- **JDPI API**: Documentation available in `tmp/jdpi-api-doc.5.2.1.pdf`
- **iugu Identity**: https://developer.iugu.com/identity/

## 📄 License

This project is licensed under the MIT License.

## 💙 About

Gupii represents friendly, accessible PIX payments for the Brazilian market. Built with modern Rails practices and enterprise-grade observability for reliable financial integrations.

---

**Made with ❤️ for the Brazilian PIX ecosystem**

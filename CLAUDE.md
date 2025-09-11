# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Gupii** is a PIX payment system integration project for the Brazilian Central Bank's instant payment system. PIX enables real-time payments and transfers 24/7, and this project integrates with the JDPI (Diretório de Identificadores de Contas Transacionais) API to facilitate PIX transactions.

The project mascot is **Gupii** 🐹 - a friendly blue gopher-like character with iugu branding, representing the project's focus on making PIX payments accessible and user-friendly.

### Technical Architecture

**Monolithic Rails 8 Application** with dual scopes:
- **Admin UI**: Web interface for PIX key management, infraction reports, and transaction refunds
- **API**: External endpoints for client applications with polling-based communication

**Database Strategy**:
- PostgreSQL server with environment-specific databases:
  - `gupii_[env]` - Main application data
  - `gupii_cache_[env]` - Solid Cache storage
  - `gupii_queue_[env]` - Solid Queue jobs
- Redis for additional caching layer

**Integration Pattern**:
- Service-oriented JDPI integration (`app/services/jdpi/`)
- Local models with external API reference separation
- Initial focus: MED (Mecanismo Especial de Devolução)
- Client polling strategy for real-time updates

## Development Environment

This project uses a comprehensive DevContainer setup with full observability stack:

### Core Infrastructure
- **Rails 8** (latest stable) with PostgreSQL and Redis
- **Solid Cache** and **Solid Queue** with dedicated databases
- **Development Container** with VS Code integration
- **Docker Compose** orchestration for all services

### Monitoring & Observability
- **Prometheus** (Port 9090): Metrics collection
- **Grafana** (Port 3001): Dashboards and visualization
  - Username: `admin` / Password: `admin123`
- **Jaeger** (Port 16686): Distributed tracing
- **StatsD/Graphite** (Port 8080): Metrics aggregation

### Development Tools
- **pgAdmin** (Port 5050): PostgreSQL web interface
  - Email: `admin@gupii.dev` / Password: `admin123`
- **MailHog** (Port 8025): Email testing interface
- **MinIO** (Port 9000/9001): S3-compatible object storage
  - Access Key: `minioadmin` / Secret Key: `minioadmin123`

### Unified Access
- **Nginx Reverse Proxy** (Port 80) provides unified access:
  - `/` → Rails app
  - `/grafana/` → Grafana
  - `/prometheus/` → Prometheus
  - `/pgadmin/` → pgAdmin
  - `/mail/` → MailHog
  - `/minio/` → MinIO Console
  - `/jaeger/` → Jaeger UI

## Common Commands

### Development Setup
- **Start Environment**: Open in VS Code with Dev Containers extension
- **Ruby Version**: 3.4.5 (specified in `.ruby-version` and `Gemfile`)
- **Rails Version**: 8.0 (latest stable)
- **Initial Setup**: `rails new . --database=postgresql --skip-git` (if needed)
- **Install Dependencies**: `bundle install`
- **Database Setup**: Multiple PostgreSQL databases via DevContainer
- **Queue Setup**: Solid Queue with dedicated database
- **Cache Setup**: Solid Cache with dedicated database

### Development Server
- **Main Application**: http://localhost:3000
- **Admin UI**: `/admin` routes for PIX management
- **API Endpoints**: `/api/v1` for client applications
- **Polling Endpoint**: `/api/v1/events/poll` for client updates

### Code Quality (Using Reference Project)
The `tmp/platform2-app-boleto` contains a reference Rails project for Tailwind templates and frontend patterns:
- **Linting**: `rake rubocop` 
- **Type Checking**: `rake typecheck` (Solargraph)
- **Auto-fix**: `rake format`

## Reference Materials

### Frontend Templates
- **Location**: `/tmp/platform2-app-boleto/`
- **Purpose**: Tailwind CSS templates and frontend components
- **Usage**: Reference only - copy patterns and styles to main Gupii project

### JDPI Documentation
- **API Documentation**: `tmp/jdpi-api-doc.5.2.1.pdf`
- **Purpose**: Official JDPI API specification for PIX integration
- **Version**: 5.2.1 (Central Bank of Brazil)

### Project Assets
- **Logo/Mascot**: `tmp/gupii.png` - The official Gupii mascot
- **Branding**: Blue friendly character with iugu integration

## Architecture Focus

### Authentication & Authorization
- **Provider**: iugu Identity Provider (OAuth 2.0 + JWT)
- **Base URL**: `https://identity.iugu.com`
- **Implementation**: Based on `platform2-app-boleto` reference architecture

**Key Components**:
- **IdentityClient** (`lib/identity_client.rb`): JWT validation, OAuth2 client setup
- **AuthBaseController**: Base authentication for admin controllers
- **JwtCache**: Token management with Redis caching
- **AppSettings**: Configuration management with env var support

**OAuth2 Flow**:
- **Authorization URL**: `/authorize` → Redirect to iugu Identity
- **Callback URL**: `/oauth2/callback` → Handle authorization code
- **Token Validation**: RS256 JWT with JWKS endpoint validation
- **Token Refresh**: Automatic refresh with 20-minute cache expiry

**Key Endpoints**:
- `GET /oauth2/callback` - OAuth2 authorization callback
- `GET /logout` - Session termination
- **JWKS**: `/.well-known/jwks.json` for token validation

**Configuration**:
- `config/application.yml` - Base application configuration
- **Rails Credentials**: `rails credentials:edit` for secrets management
- **Priority**: Rails credentials → application.yml → environment variables

### Service Architecture
- **JDPI Services**: `app/services/jdpi/` directory structure
- **MED Focus**: Start with Mecanismo Especial de Devolução
- **External References**: Separate models for API data vs local data
- **Best Practices**: Clean separation between internal and external systems

### API Design Patterns
- **Client Communication**: Polling-based strategy
- **Event Updates**: Dedicated polling endpoints per entity
- **Client Flow**: Client apps manage balances → Send PIX actions to Gupii → JDPI communication
- **Versioning**: `/api/v1` namespace for external endpoints

### PIX Integration
- **Primary Goal**: Integration with Brazil's Central Bank PIX system
- **API**: JDPI (Diretório de Identificadores de Contas Transacionais)
- **Real-time Payments**: 24/7 instant transfer capabilities
- **Compliance**: Brazilian Central Bank regulations
- **Admin Features**: PIX key management, infraction reports, transaction refunds

### Frontend Development
- **Tailwind CSS**: Use templates from `tmp/platform2-app-boleto` as reference
- **Component Patterns**: Follow Rails 8 conventions with modern CSS
- **Responsive Design**: Mobile-first approach for payment interfaces
- **Admin Interface**: Focus on PIX management workflows

### Development Workflow
1. **Service-First**: Build JDPI services with clean external/internal separation
2. **Authentication**: Integrate iugu Identity Provider for JWT-based auth
3. **Database Strategy**: Multi-database setup with Solid Cache/Queue
4. **API Design**: Polling-based endpoints for client communication
5. **Observability**: Use built-in monitoring stack for development insights

## Configuration Management

### Rails Credentials (Recommended)
Use `rails credentials:edit` to manage sensitive information:

```yaml
# config/credentials.yml.enc (encrypted)
oauth:
  client_id: your_iugu_oauth_client_id
  client_secret: your_iugu_oauth_client_secret

core:
  api_token: your_core_api_token

billing:
  app_id: your_billing_app_id

icp_signature:
  app_id: your_icp_signature_app_id

# Test environment credentials
test:
  oauth:
    client_id: test_client_id
    client_secret: test_client_secret
  core:
    api_token: test_core_token
```

### Environment Variables (DevContainer Managed)
These are automatically configured in the DevContainer:

```env
# Database URLs (automatically set)
DATABASE_URL=postgresql://postgres:postgres@postgres:5432/gupii_development
REDIS_URL=redis://redis123@redis:6379/0
RAILS_ENV=development
```

## Quick Access URLs
- Rails App: http://localhost:3000
- Grafana Dashboards: http://localhost:3001
- Database Admin: http://localhost:5050
- Email Testing: http://localhost:8025
- Metrics: http://localhost:9090
- Tracing: http://localhost:16686

## Disputes System Architecture

The **Disputes Management System** handles internal dispute processes for infraction notifications with comprehensive workflow management.

### Key Features
- **Complete CRUD Operations**: Create disputes from infraction notifications with nested routing
- **Status Management**: 7-state dispute lifecycle with proper transitions
- **Timeline Tracking**: Customer response deadlines with automatic decline capability
- **Action Management**: Approve, reject, escalate, assign, and cancel operations
- **Dashboard Analytics**: Real-time metrics and critical alerts
- **Internationalization**: Full i18n support in Portuguese

### Technical Implementation
- **Model**: `app/models/dispute.rb` with ShortId concern for display IDs
- **Controller**: `app/controllers/disputes_controller.rb` with comprehensive action handling
- **Views**: Responsive Tailwind CSS with professional UX matching infraction notifications
- **Routes**: Nested under infraction notifications + standalone dispute management
- **Database**: 6-day customer response deadline with auto-decline functionality

### Dispute Lifecycle
1. **pending_customer_response** → Customer has 6 days to respond
2. **under_internal_review** → Internal team analysis
3. **pending_resolution** → Awaiting final decision
4. **approved/rejected** → Final resolution states
5. **auto_declined** → Automatic decline after deadline
6. **escalated** → Escalated for superior review

### Business Rules
- **One dispute per infraction notification**
- **6-day customer response deadline** (7 - 1 day buffer)
- **Automatic decline** for overdue responses
- **Status transition validation** with proper workflow
- **Timeline constraints** between 1-14 days

## SPI Transaction Lookup System

The **SPI Transaction Lookup** provides real-time consultation of PIX transactions directly from the SPI (Sistema de Pagamentos Instantâneos) via JDPI API integration.

### Key Features
- **Real-time SPI Consultation**: Direct API calls to JDPI endpoint 8.4.7 without local persistence
- **End-to-End ID Validation**: 32-character E2E ID format validation with real-time feedback
- **Comprehensive Transaction Details**: Full transaction data display including status, institutions, payment methods
- **Professional UX**: Consistent design matching existing dispute/infraction notification forms
- **Complete i18n Support**: Full Portuguese localization for all interface elements

### Technical Implementation
- **Service**: `app/services/jdpi/spi_transaction_service.rb` with comprehensive API integration
- **Controller**: `app/controllers/spi_transactions_controller.rb` with form handling and error management
- **Views**: Responsive interface with search form, results display, and help sidebar
- **Routes**: `/spi_transactions` endpoint for transaction lookup functionality
- **Navigation**: Integrated in sidebar with magnifying-glass icon

### API Integration
- **JDPI Endpoint**: `GET /jdpi/spi/api/v2/lancamento/{endToEndId}`
- **Authentication**: Bearer token with JWT validation
- **Response Normalization**: Comprehensive data mapping and status translations
- **Error Handling**: Custom exceptions for invalid format, not found, and API errors

### User Experience
- **Form-based Interface**: Single field for E2E ID input with validation
- **Character Counter**: Real-time feedback for 32-character requirement
- **Results Display**: Color-coded sections for transaction details (status, payment, institutions, technical)
- **Help Sidebar**: Contextual guidance with examples and usage instructions
- **Error States**: User-friendly error messages for all failure scenarios

### Business Value
- **Customer Support**: Instant transaction verification without database queries
- **Real-time Data**: Direct access to SPI transaction status and details
- **No Local Storage**: Stateless consultation maintaining data privacy
- **Regulatory Compliance**: Official JDPI API integration following Central Bank specifications

## Important Notes

- **PIX Focus**: Brazilian Central Bank PIX integration with MED (Mecanismo Especial de Devolução)
- **Rails Version**: 8.0 (latest stable) with Ruby 3.4.5
- **Multi-Database**: Separate PostgreSQL databases for app, cache, and queue
- **Authentication**: iugu Identity Provider with JWT tokens
- **API Strategy**: Polling-based client communication pattern
- **Service Architecture**: Clean JDPI integration in `app/services/jdpi/`
- **Disputes System**: Complete lifecycle management with 6-day customer response SLA
- **SPI Transaction Lookup**: Real-time consultation via JDPI API 8.4.7 without local persistence
- **Reference Templates**: Use `tmp/platform2-app-boleto` for Tailwind patterns only
- **JDPI Documentation**: API specification in `tmp/jdpi-api-doc.5.2.1.pdf`
- **Mascot**: Gupii 🐹 represents friendly, accessible PIX payments
- **Monolithic**: Single Rails app with Admin UI + API scopes for development velocity
- **Full Stack Observability**: Comprehensive monitoring with Grafana, Prometheus, Jaeger

The project combines modern Rails 8 development with enterprise-grade observability and clean service architecture to create a robust, compliant PIX payment integration solution for the Brazilian Central Bank ecosystem.
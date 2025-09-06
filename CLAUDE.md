# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Gupii** is a PIX payment system integration project for the Brazilian Central Bank's instant payment system. PIX enables real-time payments and transfers 24/7, and this project integrates with the JDPI (Diretório de Identificadores de Contas Transacionais) API to facilitate PIX transactions.

The project mascot is **Gupii** 🐹 - a friendly blue gopher-like character with iugu branding, representing the project's focus on making PIX payments accessible and user-friendly.

## Development Environment

This project uses a comprehensive DevContainer setup with full observability stack:

### Core Infrastructure
- **Rails 7+** with PostgreSQL and Redis
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
- **Initial Setup**: `rake prepare` (if applicable)
- **Install Dependencies**: `bundle install`
- **Database Setup**: Automatic PostgreSQL setup via DevContainer

### Development Server
- **Main Application**: http://localhost:3000
- **Development Mode**: Rails auto-reloads with Tailwind CSS

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

### PIX Integration
- **Primary Goal**: Integration with Brazil's Central Bank PIX system
- **API**: JDPI (Diretório de Identificadores de Contas Transacionais)
- **Real-time Payments**: 24/7 instant transfer capabilities
- **Compliance**: Brazilian Central Bank regulations

### Frontend Development
- **Tailwind CSS**: Use templates from `tmp/platform2-app-boleto` as reference
- **Component Patterns**: Follow Rails 7+ conventions with modern CSS
- **Responsive Design**: Mobile-first approach for payment interfaces

### Development Workflow
1. **Reference First**: Check `tmp/platform2-app-boleto` for UI patterns
2. **PIX Focus**: All features should support PIX transaction flows
3. **Observability**: Use built-in monitoring stack for development insights
4. **API Integration**: Follow JDPI documentation for Central Bank compliance

## Environment Configuration

```env
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

## Important Notes

- **PIX Focus**: This is specifically for Brazilian Central Bank PIX integration
- **Ruby Version**: 3.4.5 (latest stable version)
- **Reference Templates**: Use `tmp/platform2-app-boleto` for Tailwind patterns only
- **JDPI Compliance**: Follow the API documentation in `tmp/jdpi-api-doc.5.2.1.pdf`
- **Mascot**: Gupii represents friendly, accessible PIX payments
- **Full Stack Observability**: Leverage built-in monitoring for development insights
- **DevContainer**: Everything runs in containerized environment with full tooling

The project combines modern Rails development with comprehensive observability to create a robust PIX payment integration solution.
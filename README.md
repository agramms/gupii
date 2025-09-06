# Gupii 🐹

**PIX Payment Integration System for the Brazilian Central Bank**

Gupii is a Rails 8 application that provides seamless integration with Brazil's PIX instant payment system through the JDPI (Diretório de Identificadores de Contas Transacionais) API.

![Gupii Mascot](tmp/gupii.png)

## 🚀 Features

- **PIX Key Management** - Create and manage PIX keys for instant payments
- **MED Integration** - Mecanismo Especial de Devolução (Special Refund Mechanism)
- **Infraction Reports** - Handle PIX transaction disputes and violations
- **Transaction Refunds** - Process refunds through the Central Bank system
- **Admin Dashboard** - Beautiful Tailwind CSS interface for operations
- **Client API** - RESTful API with polling for external applications
- **Multi-Database** - Separate databases for app, cache, and job queue

## 🏗️ Architecture

- **Rails 8** with Ruby 3.4.5
- **PostgreSQL** multi-database setup (main, cache, queue, cable)
- **Solid Cache & Solid Queue** for performance
- **iugu Identity Provider** authentication (OAuth2 + JWT)
- **JDPI API** integration for Central Bank compliance
- **Tailwind CSS** responsive admin interface
- **Docker** containerized deployment

## 🛠️ Development Setup

### Prerequisites

- Docker and VS Code with Dev Containers extension
- Or: Ruby 3.4.5, PostgreSQL, Redis locally

### Quick Start with Dev Containers

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-org/gupii.git
   cd gupii
   ```

2. **Open in VS Code**
   - Install the Dev Containers extension
   - Open the project in VS Code
   - Click "Reopen in Container" when prompted

3. **Setup the application**
   ```bash
   bundle install
   bin/rails db:setup
   bin/dev
   ```

4. **Visit the application**
   - Admin Dashboard: http://localhost:3000
   - API Health Check: http://localhost:3000/api/v1/health

### Local Development

1. **Install dependencies**
   ```bash
   bundle install
   ```

2. **Setup databases**
   ```bash
   bin/rails db:create:all
   bin/rails db:migrate:all
   ```

3. **Start the development server**
   ```bash
   bin/dev
   ```

## 🧪 Testing

```bash
# Run all tests
bundle exec rspec

# Run system tests
bin/rails test:system

# Run security scans
bin/brakeman
bin/rubocop
```

## 🚢 Deployment

Gupii uses **GitHub Actions** for CI/CD:

- **CI Pipeline**: Tests, security scans, Docker builds
- **Multi-Environment**: Supports staging and production
- **Automated**: Triggered on pull requests and main branch pushes

## 📡 API Usage

### Health Check
```bash
curl http://localhost:3000/api/v1/health
```

### Polling for Updates
```bash
curl http://localhost:3000/api/v1/events/poll
```

## 🔧 Configuration

Key environment variables:

```env
# Database
DATABASE_URL=postgresql://user:pass@host:5432/gupii_production
SOLID_CACHE_DATABASE_URL=postgresql://user:pass@host:5432/gupii_cache_production
SOLID_QUEUE_DATABASE_URL=postgresql://user:pass@host:5432/gupii_queue_production

# Authentication  
IUGU_IDENTITY_CLIENT_ID=your_client_id
IUGU_IDENTITY_CLIENT_SECRET=your_client_secret

# JDPI API
JDPI_BASE_URL=https://api.jdpi.bcb.gov.br
JDPI_CLIENT_ID=your_jdpi_client_id
JDPI_CLIENT_SECRET=your_jdpi_client_secret
```

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

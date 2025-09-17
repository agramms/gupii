# Development Quick Start Guide

Quick reference for getting Gupii up and running in development.

## 🚀 One-Command Setup

```bash
# 1. Install dependencies
bundle install

# 2. Start Docker services (PostgreSQL, Redis, MinIO, monitoring tools)
docker-compose --profile tools --profile domains up -d

# 3. Start all development processes (Rails + Workers + CSS watcher)
foreman start -f Procfile.dev
```

That's it! 🎉

## 📋 What This Gives You

### Running Services
- **Rails App**: https://gupii.local
- **Background Worker**: Single Solid Queue worker process
- **CSS Auto-rebuild**: Tailwind CSS watcher
- **PostgreSQL**: Multiple databases (app, cache, queue)
- **Redis**: Caching and sessions
- **MinIO**: S3-compatible file storage

### Monitoring & Debugging
- **Job Queue Admin**: https://gupii.local/admin/jobs
- **MinIO Console**: https://minio-console.gupii.local
- **Grafana Dashboards**: https://grafana.gupii.local
- **Jaeger Tracing**: https://jaeger.gupii.local
- **Graphite Metrics**: https://graphite.gupii.local

## 🔧 Individual Commands

If you prefer manual control:

```bash
# Start Docker services
docker-compose up -d                    # Essential only
docker-compose --profile tools up -d   # With monitoring

# Start Rails processes
bin/rails server                       # Web server
bin/rails solid_queue:start           # Background workers
bin/rails tailwindcss:watch           # CSS watcher

# Verify everything works
bin/verify_observability_stack
```

## 📊 Queue Management

### Background Job Queues
- **high_priority**: Disputes, fraud markings (processed first)
- **default**: Metrics, sync, notifications (standard priority)
- **low_priority**: Reports, bulk operations (processed last)

*Note: In development, a single worker processes all queues in priority order.*

### Queue Commands
```ruby
# Schedule jobs with priority
DisputeProcessingJob.set(queue: :high_priority).perform_later(dispute_id)
PspMetricsCollectionJob.perform_later  # Uses :default queue
DataExportJob.set(queue: :low_priority).perform_later(params)
```

### Job Monitoring
- Web Interface: https://gupii.local/admin/jobs
- Queue status, failed jobs, retry management
- Real-time job execution metrics

## 🎯 Next Steps

1. **Verify Setup**: Run `bin/verify_observability_stack`
2. **Check Jobs**: Visit https://gupii.local/admin/jobs
3. **Test File Upload**: Use MinIO console or Rails console
4. **Review Metrics**: Check Grafana dashboards
5. **Trace Requests**: Monitor API calls in Jaeger

## 🆘 Troubleshooting

### Common Issues

**Port conflicts**: Stop other local services on ports 3000, 5432, 6379, etc.

**SSL certificate warnings**: Accept browser security warnings for *.gupii.local domains

**Docker permission errors**: Ensure Docker daemon is running and accessible

**Queue workers not processing**: Check `/admin/jobs` for worker status and failed jobs

### Quick Fixes

```bash
# Reset Docker services
docker-compose down && docker-compose --profile tools up -d

# Restart Rails processes
pkill -f "rails server|solid_queue|tailwindcss"
foreman start -f Procfile.dev

# Check service health
docker-compose ps
curl -k https://gupii.local/up
```

## 📚 Full Documentation

- **Complete Setup**: `CLAUDE.md`
- **Observability Stack**: `docs/observability_stack_setup.md`
- **API Documentation**: `tmp/jdpi-api-doc.5.2.1.pdf`
- **UI Templates**: `tmp/platform2-app-boleto/`
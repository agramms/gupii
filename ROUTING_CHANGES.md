# Nginx Routing Configuration Changes

## Overview
The Gupii PIX system has been reconfigured to resolve nginx routing conflicts by moving the Rails application from the root path (`/`) to a subpath (`/app/`). This change allows all development services to coexist without conflicts.

## Changes Made

### 1. Nginx Configuration (`/.devcontainer/config/nginx.conf`)
- **Root Path**: Now redirects `/` → `/app/` (302 redirect)
- **Rails App**: Moved from `/` to `/app/` subpath
- **Service Paths**: All other services maintain their designated paths:
  - Grafana: `/grafana/`
  - Prometheus: `/prometheus/`
  - pgAdmin: `/pgadmin/`
  - MailHog: `/mail/`
  - MinIO Console: `/minio/`
  - Jaeger: `/jaeger/`

### 2. Rails Application Configuration

#### `config/application.rb`
- Added relative URL root configuration: `config.relative_url_root = ENV.fetch('RAILS_RELATIVE_URL_ROOT', '/app')`
- Configured i18n locales and fallbacks for Brazilian Portuguese

#### `config/environments/development.rb`
- Updated mailer URL options: `script_name: '/app'`
- Configured proper host and port for development

#### `app/controllers/authentication_controller.rb`
- Enhanced OAuth2 callback URL handling for subpath deployment
- Uses `X-Script-Name` header from nginx for proper redirects

### 3. DevContainer Configuration

#### `.devcontainer/docker-compose.yml`
- Added environment variable: `RAILS_RELATIVE_URL_ROOT: /app`
- Ensures Rails knows it's running under a subpath

### 4. Development Tools

#### `.env.example`
- Created comprehensive environment configuration template
- Documented all service URLs and configuration options

#### `bin/verify_routing`
- Created routing verification script to test all endpoints
- Validates nginx configuration and Rails subpath setup
- Checks all service accessibility through reverse proxy

## Service URLs After Changes

| Service | Old URL | New URL |
|---------|---------|---------|
| Rails App | `http://localhost/` | `http://localhost/app/` |
| Grafana | `http://localhost:3001/` | `http://localhost/grafana/` |
| Prometheus | `http://localhost:9090/` | `http://localhost/prometheus/` |
| pgAdmin | `http://localhost:5050/` | `http://localhost/pgadmin/` |
| MailHog | `http://localhost:8025/` | `http://localhost/mail/` |
| MinIO Console | `http://localhost:9001/` | `http://localhost/minio/` |
| Jaeger | `http://localhost:16686/` | `http://localhost/jaeger/` |

## Testing the Configuration

### 1. Verify nginx configuration
```bash
docker compose -f .devcontainer/docker-compose.yml exec nginx nginx -t
```

### 2. Run routing verification script
```bash
./bin/verify_routing
```

### 3. Test OAuth2 authentication flow
```bash
curl -I http://localhost/app/oauth2/callback
```

### 4. Monitor nginx logs
```bash
docker-compose logs -f nginx
```

## OAuth2 Callback Configuration

### Before (Root Path)
```
Callback URL: http://localhost/oauth2/callback
```

### After (Subpath)
```
Callback URL: http://localhost/app/oauth2/callback
```

**Important**: Update your OAuth2 provider (iugu Identity) configuration to use the new callback URL.

## API Endpoints

All API endpoints are now prefixed with `/app`:

- Health Check: `http://localhost/app/up`
- API v1: `http://localhost/app/api/v1/`
- Infraction Notifications: `http://localhost/app/api/v1/infraction_notifications`

## Asset Serving

Rails assets are properly served through the subpath:
- Application CSS: `http://localhost/app/assets/application.css`
- Application JS: `http://localhost/app/assets/application.js`

## Monitoring and Observability

The nginx configuration includes proper proxy headers for:
- `X-Real-IP`: Client IP address
- `X-Forwarded-For`: Proxy chain
- `X-Forwarded-Proto`: Original protocol (HTTP/HTTPS)
- `X-Script-Name`: Subpath for Rails (`/app`)
- `X-Forwarded-Prefix`: Additional prefix header

## Troubleshooting

### Common Issues

1. **404 on Rails routes**: Ensure `RAILS_RELATIVE_URL_ROOT=/app` is set
2. **Assets not loading**: Check nginx proxy headers and Rails asset configuration
3. **OAuth2 callback fails**: Verify callback URL in identity provider matches `/app/oauth2/callback`
4. **Service not accessible**: Run `./bin/verify_routing` to identify issues

### Rollback Procedure

If you need to rollback to root path deployment:
1. Remove `RAILS_RELATIVE_URL_ROOT=/app` from docker-compose.yml
2. Update nginx.conf to proxy `/` to Rails instead of `/app/`
3. Remove subpath handling from authentication controller
4. Update mailer configuration to remove `script_name`

## Best Practices

1. **Always use relative URLs** in Rails views and controllers
2. **Test OAuth2 flow** after any routing changes
3. **Use the verification script** before committing changes
4. **Monitor nginx logs** during development
5. **Keep documentation updated** when adding new services

## Performance Considerations

- Root path redirect adds minimal overhead (302 → 200)
- Proxy headers are lightweight
- Subpath deployment is production-ready if needed
- All services maintain their individual performance characteristics

---

**Last Updated**: $(date)
**Configuration Version**: 1.0
**Rails Version**: 8.0
**Nginx Version**: Latest stable
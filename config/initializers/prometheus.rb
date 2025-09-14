require 'prometheus/client'

# Configure Prometheus for Rails
unless Rails.env.test?
  # Custom Prometheus registry (use default configuration)
  prometheus = Prometheus::Client.registry

  # Rails metrics
  rails_requests = prometheus.counter(
    :rails_requests_total,
    docstring: 'Total number of Rails requests',
    labels: [:controller, :action, :method, :status]
  )

  rails_request_duration = prometheus.histogram(
    :rails_request_duration_seconds,
    docstring: 'Rails request duration',
    labels: [:controller, :action, :method]
  )

  # Database metrics
  database_connections = prometheus.gauge(
    :rails_database_connections_total,
    docstring: 'Total number of database connections'
  )

  # Custom business metrics
  psp_sync_duration = prometheus.histogram(
    :psp_sync_duration_seconds,
    docstring: 'Duration of PSP synchronization operations',
    labels: [:status]
  )

  fraud_markings_created = prometheus.counter(
    :fraud_markings_created_total,
    docstring: 'Total number of fraud markings created',
    labels: [:status, :priority]
  )

  # Store metrics in Rails application for easy access
  Rails.application.config.prometheus_metrics = {
    rails_requests: rails_requests,
    rails_request_duration: rails_request_duration,
    database_connections: database_connections,
    psp_sync_duration: psp_sync_duration,
    fraud_markings_created: fraud_markings_created
  }
end
# frozen_string_literal: true

# StatsD Configuration for Metrics Collection
# Sends application metrics to Graphite via StatsD for monitoring and visualization

require "statsd"

# Initialize StatsD client with configuration from AppConfig
statsd_host = AppConfig.get("statsd_host", "localhost")
statsd_port = AppConfig.get("statsd_port", 8125)
statsd_namespace = AppConfig.get("statsd_namespace", "gupii")

begin
  # Create global StatsD client instance
  StatsD = ::Statsd.new(statsd_host, statsd_port)
  StatsD.namespace = statsd_namespace

  # Test connection in development/test environments
  if Rails.env.development? || Rails.env.test?
    begin
      StatsD.increment("application.startup")
      Rails.logger.info "[StatsD] Connected to #{statsd_host}:#{statsd_port} with namespace '#{statsd_namespace}'"
    rescue => e
      Rails.logger.warn "[StatsD] Connection test failed: #{e.message} (metrics will be dropped silently)"
    end
  end

  Rails.logger.info "[StatsD] Initialized successfully"

rescue => e
  Rails.logger.error "[StatsD] Initialization failed: #{e.message}"

  # Create a null client that silently drops metrics to prevent errors
  StatsD = Class.new do
    def self.method_missing(method_name, *args, **kwargs, &block)
      # Silently ignore all metric calls if StatsD is unavailable
      nil
    end

    def self.respond_to_missing?(method_name, include_private = false)
      true
    end
  end

  Rails.logger.warn "[StatsD] Using null client - metrics will be dropped silently"
end

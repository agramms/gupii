# frozen_string_literal: true

class MetricsController < ApplicationController
  # Simplified - no authentication skipping needed

  def show
    begin
      # Try to use Prometheus client if available and properly configured
      if defined?(Prometheus::Client) && defined?(Prometheus::Client::Formats)
        registry = Prometheus::Client.registry
        render plain: Prometheus::Client::Formats::Text.marshal(registry),
               content_type: "text/plain; version=0.0.4; charset=utf-8"
      else
        # Fallback to basic metrics - this is working fine
        metrics = generate_basic_metrics
        render plain: metrics.join("\n") + "\n",
               content_type: "text/plain; version=0.0.4; charset=utf-8"
      end
    rescue => e
      Rails.logger.error "Error serving Prometheus metrics: #{e.message}"
      Rails.logger.debug e.backtrace.join("\n") if Rails.logger.debug?

      # Always fallback to basic metrics on any error
      metrics = generate_basic_metrics
      render plain: metrics.join("\n") + "\n",
             content_type: "text/plain; version=0.0.4; charset=utf-8"
    end
  end

  private

  def generate_basic_metrics
    uptime = Rails.application.config.start_time ?
             (Time.current - Rails.application.config.start_time).to_i :
             Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i

    metrics = [
      "# HELP rails_uptime_seconds Rails application uptime in seconds",
      "# TYPE rails_uptime_seconds gauge",
      "rails_uptime_seconds #{uptime}",
      "",
      "# HELP rails_info Rails application information",
      "# TYPE rails_info gauge",
      "rails_info{version=\"#{Rails.version}\",environment=\"#{Rails.env}\"} 1",
    ]

    # Add simple metrics if available
    if Rails.application.config.respond_to?(:simple_metrics) && Rails.application.config.simple_metrics
      simple = Rails.application.config.simple_metrics
      metrics += [
        "",
        "# HELP http_requests_total Total number of HTTP requests",
        "# TYPE http_requests_total counter",
        "http_requests_total #{simple[:requests_total] || 0}",
        "",
        "# HELP http_request_duration_seconds Average HTTP request duration in seconds",
        "# TYPE http_request_duration_seconds gauge",
        "http_request_duration_seconds #{simple[:avg_response_time] || 0}",
        "",
        "# HELP http_request_last_duration_seconds Last HTTP request duration in seconds",
        "# TYPE http_request_last_duration_seconds gauge",
        "http_request_last_duration_seconds #{simple[:last_request_duration] || 0}",
      ]
    end

    metrics
  end

  def defined_authenticate_user?
    respond_to?(:authenticate_user!, true)
  end
end

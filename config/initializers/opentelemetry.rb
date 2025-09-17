# frozen_string_literal: true

# OpenTelemetry Configuration for Distributed Tracing
# Instruments Rails, Faraday, Redis, and other components for request tracing
# Exports traces to Jaeger for visualization and debugging

require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry/instrumentation/all"

# Only enable tracing in development and production
# Skip in test environment to avoid overhead
unless Rails.env.test?
  begin
    # Configure OpenTelemetry SDK
    OpenTelemetry::SDK.configure do |c|
      # Service identification
      c.service_name = AppConfig.get("otel_service_name", "gupii")
      c.service_version = AppConfig.get("otel_service_version", "1.0.0")

      # Resource attributes
      c.resource = OpenTelemetry::SDK::Resources::Resource.create({
        "service.name" => AppConfig.get("otel_service_name", "gupii"),
        "service.version" => AppConfig.get("otel_service_version", "1.0.0"),
        "service.environment" => Rails.env,
        "service.instance.id" => "#{`hostname`.strip}-#{Process.pid}",
      })

      # Configure OTLP exporter to send traces to Jaeger
      otlp_endpoint = AppConfig.get("otel_exporter_otlp_endpoint", "http://localhost:4318")
      c.add_span_processor(
        OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
          OpenTelemetry::Exporter::OTLP::Exporter.new(
            endpoint: "#{otlp_endpoint}/v1/traces",
            headers: {},
            compression: "none"
          )
        )
      )

      # Configure sampling (100% in development, configurable in production)
      sample_rate = AppConfig.get("otel_sample_rate", Rails.env.development? ? 1.0 : 0.1).to_f
      c.sampler = OpenTelemetry::SDK::Trace::Samplers::TraceIdRatioBasedSampler.new(sample_rate)

      # Auto-instrument common Rails components
      c.use_all({
        # Rails framework instrumentation
        "OpenTelemetry::Instrumentation::Rails" => { enabled: true },
        "OpenTelemetry::Instrumentation::ActionView" => { enabled: true },
        "OpenTelemetry::Instrumentation::ActiveRecord" => { enabled: true },
        "OpenTelemetry::Instrumentation::ActiveJob" => { enabled: true },

        # HTTP client instrumentation (for JDPI API calls)
        "OpenTelemetry::Instrumentation::Faraday" => { enabled: true },
        "OpenTelemetry::Instrumentation::Net::HTTP" => { enabled: true },

        # Redis instrumentation (for caching and background jobs)
        "OpenTelemetry::Instrumentation::Redis" => { enabled: true },

        # Rack instrumentation (for HTTP request/response)
        "OpenTelemetry::Instrumentation::Rack" => { enabled: true },

        # Disable noisy instrumentations in development
        "OpenTelemetry::Instrumentation::PG" => { enabled: !Rails.env.development? },
      })
    end

    # Create a tracer for manual instrumentation in services
    Rails.application.config.otel_tracer = OpenTelemetry.tracer_provider.tracer(
      "gupii-application",
      AppConfig.get("otel_service_version", "1.0.0")
    )

    Rails.logger.info "[OpenTelemetry] Initialized successfully - traces will be sent to #{AppConfig.get('otel_exporter_otlp_endpoint', 'http://localhost:4318')}"

  rescue => e
    Rails.logger.error "[OpenTelemetry] Initialization failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n") if Rails.env.development?

    # Provide a null tracer to prevent errors
    Rails.application.config.otel_tracer = Class.new do
      def self.in_span(name, attributes: {}, &block)
        yield(nil, nil) if block_given?
      end

      def self.method_missing(method_name, *args, **kwargs, &block)
        yield(nil, nil) if block_given?
        nil
      end

      def self.respond_to_missing?(method_name, include_private = false)
        true
      end
    end

    Rails.logger.warn "[OpenTelemetry] Using null tracer - tracing disabled"
  end
else
  Rails.logger.info "[OpenTelemetry] Disabled in test environment"

  # Provide a null tracer for test environment
  Rails.application.config.otel_tracer = Class.new do
    def self.in_span(name, attributes: {}, &block)
      yield(nil, nil) if block_given?
    end

    def self.method_missing(method_name, *args, **kwargs, &block)
      yield(nil, nil) if block_given?
      nil
    end

    def self.respond_to_missing?(method_name, include_private = false)
      true
    end
  end
end
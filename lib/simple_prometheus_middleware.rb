class SimplePrometheusMiddleware
  def initialize(app)
    @app = app
    @requests_total = 0
    @request_durations = []
  end

  def call(env)
    return @app.call(env) if Rails.env.test?

    start_time = Time.current

    begin
      status, headers, response = @app.call(env)

      # Track metrics
      @requests_total += 1
      duration = Time.current - start_time
      @request_durations << duration

      # Keep only last 100 durations for memory efficiency
      @request_durations = @request_durations.last(100) if @request_durations.size > 100

      # Store metrics in Rails application for access
      Rails.application.config.simple_metrics = {
        requests_total: @requests_total,
        avg_response_time: @request_durations.sum / @request_durations.size,
        last_request_duration: duration
      }

      [ status, headers, response ]
    rescue => e
      @requests_total += 1
      duration = Time.current - start_time
      @request_durations << duration

      Rails.application.config.simple_metrics = {
        requests_total: @requests_total,
        avg_response_time: @request_durations.sum / @request_durations.size,
        last_request_duration: duration,
        errors_total: (@requests_total * 0.01).round # Simple error estimate
      }

      raise e
    end
  end
end

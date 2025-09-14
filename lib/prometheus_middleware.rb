class PrometheusMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) if Rails.env.test?

    start_time = Time.current
    
    begin
      status, headers, response = @app.call(env)
      
      # Extract request info
      request = ActionDispatch::Request.new(env)
      controller_action = extract_controller_action(env)
      
      # Record metrics
      record_request_metrics(
        controller: controller_action[:controller],
        action: controller_action[:action], 
        method: request.method,
        status: status.to_s,
        duration: Time.current - start_time
      )
      
      [status, headers, response]
    rescue => e
      # Record error metrics
      record_request_metrics(
        controller: 'unknown',
        action: 'unknown',
        method: env['REQUEST_METHOD'] || 'unknown',
        status: '500',
        duration: Time.current - start_time
      )
      
      raise e
    end
  end

  private

  def extract_controller_action(env)
    # Try to extract from Rails routing
    if env['action_dispatch.request.path_parameters']
      params = env['action_dispatch.request.path_parameters']
      {
        controller: params[:controller] || 'unknown',
        action: params[:action] || 'unknown'
      }
    else
      { controller: 'unknown', action: 'unknown' }
    end
  end

  def record_request_metrics(controller:, action:, method:, status:, duration:)
    return unless Rails.application.config.prometheus_metrics

    metrics = Rails.application.config.prometheus_metrics

    # Increment request counter
    metrics[:rails_requests].increment(
      {
        controller: controller,
        action: action,
        method: method,
        status: status
      }
    )

    # Record request duration
    metrics[:rails_request_duration].observe(
      duration,
      {
        controller: controller,
        action: action,
        method: method
      }
    )
  rescue => e
    Rails.logger.error "Failed to record Prometheus metrics: #{e.message}"
  end
end
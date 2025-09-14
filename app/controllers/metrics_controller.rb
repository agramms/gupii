class MetricsController < ApplicationController
  def show
    # Return basic metrics for Prometheus scraping
    metrics = []
    
    # Basic Rails metrics
    metrics << "# HELP rails_requests_total Total number of Rails requests"
    metrics << "# TYPE rails_requests_total counter"
    metrics << "rails_requests_total{controller=\"metrics\",action=\"show\",method=\"GET\",status=\"200\"} 1"
    
    metrics << "# HELP rails_uptime_seconds Rails application uptime in seconds"  
    metrics << "# TYPE rails_uptime_seconds gauge"
    metrics << "rails_uptime_seconds #{Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i}"
    
    metrics << "# HELP rails_info Rails application information"
    metrics << "# TYPE rails_info gauge"
    metrics << "rails_info{version=\"#{Rails.version}\",environment=\"#{Rails.env}\"} 1"
    
    render plain: metrics.join("\n") + "\n",
           content_type: "text/plain; version=0.0.4; charset=utf-8"
  end
end
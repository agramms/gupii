class Api::V1::BaseController < ApplicationController
  # Base controller for API endpoints
  
  before_action :authenticate_api_client!
  before_action :set_default_format
  
  rescue_from StandardError, with: :handle_error
  
  protected
  
  def authenticate_api_client!
    # TODO: Implement JWT token validation for API clients
    # For now, we'll skip authentication in development
    return if Rails.env.development?
    
    head :unauthorized unless valid_api_token?
  end
  
  def valid_api_token?
    # TODO: Implement API token validation
    false
  end
  
  def set_default_format
    request.format = :json
  end
  
  def handle_error(error)
    Rails.logger.error "API Error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    render json: {
      error: {
        message: "Internal server error",
        code: "INTERNAL_ERROR"
      }
    }, status: :internal_server_error
  end
  
  def render_success(data = {}, status = :ok)
    render json: {
      success: true,
      data: data
    }, status: status
  end
  
  def render_error(message, code = "ERROR", status = :bad_request)
    render json: {
      success: false,
      error: {
        message: message,
        code: code
      }
    }, status: status
  end
end
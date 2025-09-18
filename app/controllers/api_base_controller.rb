# frozen_string_literal: true

class ApiBaseController < ActionController::API
  # Include basic Rails API functionality
  include ActionController::Cookies
  include ActionController::RequestForgeryProtection

  # Handle API errors consistently
  rescue_from StandardError, with: :handle_api_error

  private

  def authenticate_api_client
    # Extract API token from Authorization header
    token = extract_token_from_header

    unless token && valid_api_token?(token)
      render json: {
        success: false,
        error: "UNAUTHORIZED",
        message: "Invalid or missing API token",
      }, status: :unauthorized
      return false
    end

    true
  end

  def extract_token_from_header
    auth_header = request.headers["Authorization"]
    return nil unless auth_header&.start_with?("Bearer ")

    auth_header[7..-1] # Remove "Bearer " prefix
  end

  def valid_api_token?(token)
    # Basic token validation - in production this would validate against
    # a proper API key management system
    expected_token = AppConfig.get("GUPII_API_TOKEN")
    return false unless expected_token

    # Use secure comparison to prevent timing attacks
    ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
  end

  def handle_api_error(exception)
    case exception
    when ActionController::ParameterMissing
      render json: {
        success: false,
        error: "MISSING_PARAMETER",
        message: "Required parameter missing: #{exception.param}",
      }, status: :bad_request
    when ActiveRecord::RecordNotFound
      render json: {
        success: false,
        error: "NOT_FOUND",
        message: "Requested resource not found",
      }, status: :not_found
    when ActionController::UnpermittedParameters
      render json: {
        success: false,
        error: "INVALID_PARAMETERS",
        message: "Invalid parameters provided",
      }, status: :bad_request
    else
      Rails.logger.error "API Error: #{exception.class}: #{exception.message}"
      Rails.logger.error exception.backtrace.join("\n") if Rails.env.development?

      render json: {
        success: false,
        error: "INTERNAL_ERROR",
        message: "An internal error occurred",
      }, status: :internal_server_error
    end
  end
end

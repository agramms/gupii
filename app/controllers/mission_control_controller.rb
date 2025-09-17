# frozen_string_literal: true

require "ostruct"

class MissionControlController < AuthBaseController
  # Mission Control - Jobs will inherit from this controller
  # This ensures all job admin access requires authentication

  # Skip CSRF protection for API endpoints (Mission Control uses AJAX)
  skip_before_action :verify_authenticity_token, if: :api_request?

  # Override the parent's authentication to handle API requests
  def authenticated
    return if Rails.env.test? || logged?

    # Handle API requests differently than regular page requests
    if api_request?
      render json: { error: "Authentication required" }, status: :unauthorized
      return
    end

    # Use parent's redirect logic for regular requests
    redirect_user_to_auth
  end

  private

  def api_request?
    request.format.json? || request.xhr?
  end
end

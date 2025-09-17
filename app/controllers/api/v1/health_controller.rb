# frozen_string_literal: true

class Api::V1::HealthController < Api::V1::BaseController
  skip_before_action :authenticate_api_client!

  def show
    render_success({
      status: "healthy",
      timestamp: Time.current.iso8601,
      version: "1.0.0",
      environment: Rails.env,
    })
  end
end

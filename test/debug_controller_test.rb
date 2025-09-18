# frozen_string_literal: true

require "test_helper"

class DebugControllerTest < ActionDispatch::IntegrationTest
  test "debug PSP controller index" do
    # Create a PSP first
    psp = PaymentServiceProvider.create!(valid_psp_attributes)
    # Try to access the index
    begin
      get payment_service_providers_path
    rescue => e
      # Exception occurred during request
    end

    # Look for error details in the HTML
    if response.body.include?("Application Trace")
      # Rails error page detected
    end

    # Just assert something basic
    assert_response :success
  end
end

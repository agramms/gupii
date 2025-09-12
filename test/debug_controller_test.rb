require 'test_helper'

class DebugControllerTest < ActionDispatch::IntegrationTest
  test "debug PSP controller index" do
    # Create a PSP first
    psp = PaymentServiceProvider.create!(valid_psp_attributes)
    puts "Created PSP: #{psp.id}"
    puts "PSP count: #{PaymentServiceProvider.count}"
    
    # Try to access the index
    begin
      get payment_service_providers_path
    rescue => e
      puts "Exception during request: #{e.class}: #{e.message}"
      puts e.backtrace[0..5].join("\n")
    end
    
    puts "Response status: #{response.status}"
    puts "Response content type: #{response.content_type}"
    puts "Response body (first 500 chars): #{response.body[0..500]}"
    
    # Look for error details in the HTML
    if response.body.include?("Application Trace")
      puts "Found Application Trace in response - this is a Rails error page"
    end
    
    # Just assert something basic
    assert_response :success
  end
end
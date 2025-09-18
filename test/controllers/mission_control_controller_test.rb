# frozen_string_literal: true

require "test_helper"

class MissionControlControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user_id = "test-user-123"
  end

  test "should allow access in test environment" do
    # Test environment should skip authentication
    get jobs_path

    assert_response :success
  end

  test "should require authentication in non-test environment" do
    # Mock Rails.env to return development
    Rails.env.expects(:test?).returns(false).at_least_once

    get jobs_path

    # Should redirect to authentication
    assert_response :redirect
  end

  test "should handle JSON API requests when not authenticated" do
    Rails.env.expects(:test?).returns(false).at_least_once

    get jobs_path, headers: { "Accept" => "application/json" }

    assert_response :unauthorized
    assert_equal "application/json", response.content_type

    json_response = JSON.parse(response.body)
    assert_equal "Authentication required", json_response["error"]
  end

  test "should handle AJAX requests when not authenticated" do
    Rails.env.expects(:test?).returns(false).at_least_once

    get jobs_path, xhr: true

    assert_response :unauthorized
    assert_equal "application/json", response.content_type

    json_response = JSON.parse(response.body)
    assert_equal "Authentication required", json_response["error"]
  end

  test "should allow access when authenticated" do
    Rails.env.expects(:test?).returns(false).at_least_once
    session[:user_id] = @user_id

    # Mock the logged? method to return true
    @controller.expects(:logged?).returns(true).at_least_once

    get jobs_path

    assert_response :success
  end

  test "should properly identify API requests" do
    controller = MissionControlController.new

    # Mock request object
    mock_request = mock
    mock_request.expects(:format).returns(mock(json?: true))
    mock_request.expects(:xhr?).returns(false)
    controller.stubs(:request).returns(mock_request)

    assert controller.send(:api_request?)
  end

  test "should properly identify AJAX requests" do
    controller = MissionControlController.new

    # Mock request object
    mock_request = mock
    mock_request.expects(:format).returns(mock(json?: false))
    mock_request.expects(:xhr?).returns(true)
    controller.stubs(:request).returns(mock_request)

    assert controller.send(:api_request?)
  end

  test "should properly identify regular requests" do
    controller = MissionControlController.new

    # Mock request object
    mock_request = mock
    mock_request.expects(:format).returns(mock(json?: false))
    mock_request.expects(:xhr?).returns(false)
    controller.stubs(:request).returns(mock_request)

    assert_not controller.send(:api_request?)
  end
end
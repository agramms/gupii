# frozen_string_literal: true

require "test_helper"

class AuthTestControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Mock session data for authenticated tests
    @user_id = "test-user-123"
    @access_token = "valid-jwt-token"
  end

  test "should return authentication status when not logged in" do
    get auth_test_path

    assert_response :success
    assert_equal "application/json", response.content_type

    json_response = JSON.parse(response.body)
    assert_equal false, json_response["authenticated"]
    assert_nil json_response["user_id"]
    assert_equal false, json_response["has_access_token"]
    assert_equal false, json_response["current_user_present"]
  end

  test "should return authentication status when logged in" do
    # Mock authentication by setting session
    session[:user_id] = @user_id

    # Mock JwtCache to return access token
    JwtCache.expects(:read_access_token).with(@user_id).returns(@access_token)

    get auth_test_path

    assert_response :success
    assert_equal "application/json", response.content_type

    json_response = JSON.parse(response.body)
    assert_equal true, json_response["authenticated"]
    assert_equal @user_id, json_response["user_id"]
    assert_equal true, json_response["has_access_token"]
    # current_user_present will be false in test without full auth setup
    assert_equal false, json_response["current_user_present"]
  end

  test "should handle missing access token" do
    session[:user_id] = @user_id

    # Mock JwtCache to return nil (no token)
    JwtCache.expects(:read_access_token).with(@user_id).returns(nil)

    get auth_test_path

    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal true, json_response["authenticated"]
    assert_equal @user_id, json_response["user_id"]
    assert_equal false, json_response["has_access_token"]
    assert_equal false, json_response["current_user_present"]
  end

  test "should return valid JSON structure" do
    get auth_test_path

    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("authenticated")
    assert json_response.key?("user_id")
    assert json_response.key?("has_access_token")
    assert json_response.key?("current_user_present")
  end
end

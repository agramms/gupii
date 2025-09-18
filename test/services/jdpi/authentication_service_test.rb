# frozen_string_literal: true

require "test_helper"

class Jdpi::AuthenticationServiceTest < ActiveSupport::TestCase
  setup do
    @service = Jdpi::AuthenticationService.new
  end

  test "should generate JWT token successfully" do
    # Mock successful token generation
    mock_token = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.test.signature"

    @service.expects(:generate_jwt_payload).returns({
      iss: "gupii",
      aud: "jdpi",
      iat: Time.current.to_i,
      exp: 5.minutes.from_now.to_i,
      sub: "system",
    })

    @service.expects(:sign_jwt).returns(mock_token)

    token = @service.get_access_token

    assert_equal mock_token, token
  end

  test "should handle JWT generation failure" do
    @service.expects(:generate_jwt_payload).raises(StandardError.new("Key not found"))

    assert_raises(Jdpi::AuthenticationService::AuthenticationError) do
      @service.get_access_token
    end
  end

  test "should generate valid JWT payload" do
    freeze_time = Time.current
    Time.stubs(:current).returns(freeze_time)

    payload = @service.send(:generate_jwt_payload)

    assert_equal "gupii", payload[:iss]
    assert_equal "jdpi", payload[:aud]
    assert_equal "system", payload[:sub]
    assert_equal freeze_time.to_i, payload[:iat]
    assert_equal (freeze_time + 5.minutes).to_i, payload[:exp]
    assert payload[:jti].present?
  end

  test "should validate token expiration" do
    expired_payload = {
      iss: "gupii",
      aud: "jdpi",
      iat: 1.hour.ago.to_i,
      exp: 30.minutes.ago.to_i,
      sub: "system",
    }

    assert_not @service.send(:token_valid?, expired_payload)
  end

  test "should validate token not yet valid" do
    future_payload = {
      iss: "gupii",
      aud: "jdpi",
      iat: 1.hour.from_now.to_i,
      exp: 2.hours.from_now.to_i,
      sub: "system",
    }

    assert_not @service.send(:token_valid?, future_payload)
  end

  test "should validate current token" do
    current_payload = {
      iss: "gupii",
      aud: "jdpi",
      iat: 1.minute.ago.to_i,
      exp: 4.minutes.from_now.to_i,
      sub: "system",
    }

    assert @service.send(:token_valid?, current_payload)
  end

  test "should cache valid tokens" do
    mock_token = "valid.jwt.token"

    # First call should generate token
    @service.expects(:generate_jwt_payload).once.returns({
      iss: "gupii",
      aud: "jdpi",
      iat: Time.current.to_i,
      exp: 5.minutes.from_now.to_i,
      sub: "system",
    })
    @service.expects(:sign_jwt).once.returns(mock_token)

    token1 = @service.get_access_token
    token2 = @service.get_access_token

    assert_equal mock_token, token1
    assert_equal mock_token, token2
  end

  test "should refresh expired cached tokens" do
    # Mock expired token first
    expired_token = "expired.jwt.token"
    valid_token = "valid.jwt.token"

    # First call returns expired token
    @service.expects(:generate_jwt_payload).twice.returns(
      {
        iss: "gupii",
        aud: "jdpi",
        iat: 1.hour.ago.to_i,
        exp: 30.minutes.ago.to_i,
        sub: "system",
      },
      {
        iss: "gupii",
        aud: "jdpi",
        iat: Time.current.to_i,
        exp: 5.minutes.from_now.to_i,
        sub: "system",
      }
    )

    @service.expects(:sign_jwt).twice.returns(expired_token, valid_token)

    # First call should cache expired token
    token1 = @service.get_access_token
    # Second call should refresh with new token
    token2 = @service.get_access_token

    assert_equal expired_token, token1
    assert_equal valid_token, token2
  end

  test "should handle missing configuration" do
    # Mock missing JWT configuration by making sign_jwt fail
    @service.expects(:sign_jwt).raises(StandardError.new("Key not found"))

    assert_raises(Jdpi::AuthenticationService::AuthenticationError) do
      @service.get_access_token
    end
  end
end

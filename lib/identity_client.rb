require "net/http"
require "jwt"

module IdentityClient
  module_function

  Error = Struct.new(:message, :status)
  Response = Struct.new(:decoded_token, :error)

  def platform_audience(*path)
    client_id = AppSettings.get(*path)
    "Iugu.Platform.#{client_id}"
  end

  def decode_token(token, aud = nil)
    aud ||= platform_audience(:oauth, :client_id)

    options = {
      algorithm: [ "RS256" ],
      iss: "#{AppSettings::IDENTITY_BASE_URL}/",
      verify_iss: true,
      aud:,
      verify_aud: true,
      jwks: { keys: get_jwks[:keys] }
    }

    JWT.decode(token, nil, true, options)
  end

  def get_jwks
    Rails.cache.fetch("well_known_jwks", expires_in: 12.hours) do
      jwks_uri = URI("#{AppSettings::IDENTITY_BASE_URL}/.well-known/jwks.json")
      jwks_response = Net::HTTP.get_response jwks_uri
      JSON.parse(jwks_response.body).deep_symbolize_keys
    end
  end

  def validate_token(token, audience = nil)
    jwks_response = get_jwks

    if jwks_response[:keys].blank?
      error = Error.new(message: "Unable to verify credentials", status: :internal_server_error)
      return Response.new(nil, error)
    end

    decoded_token = decode_token(token, audience)

    Response.new(decoded_token, nil)
  rescue JWT::DecodeError
    error = Error.new("Bad credentials", :unauthorized)
    Response.new(nil, error)
  end

  def from_hash(hash) = OAuth2::AccessToken.from_hash(oauth2_client, hash)

  def authorize_url(redirect_host:)
    # Include subpath in development mode for proper OAuth callback routing
    callback_path = "/oauth2/callback"
    if Rails.env.development? && Rails.application.config.relative_url_root.present?
      callback_path = "#{Rails.application.config.relative_url_root}#{callback_path}"
    end

    redirect_uri = "#{redirect_host}#{callback_path}"
    oauth2_client.auth_code.authorize_url(redirect_uri:)
  end

  def oauth2_client
    @oauth2_client ||= OAuth2::Client.new(
      AppSettings::Oauth::CLIENT_ID,
      AppSettings::Oauth::CLIENT_SECRET,
      site: AppSettings::IDENTITY_BASE_URL,
      authorize_url: "/authorize",
      token_url: "/token"
    )
  end

  def client_access_token(audience_key)
    audience = platform_audience(audience_key, :app_id)
    cache_key = "client_access_token/#{audience_key}/#{audience}"

    Rails.cache.fetch(cache_key, expires_in: 50.minutes) do
      token = oauth2_client
        .client_credentials
        .get_token(audience: audience)

      Rails.logger.debug "[IdentityClient] New client token obtained for audience: #{audience_key}"
      token
    end
  rescue OAuth2::Error => e
    Rails.logger.error "[IdentityClient] Failed to get client access token for #{audience_key}: #{e.message}"
    raise e
  end

  def bearer_access_token(audience_key) = "Bearer #{client_access_token(audience_key).token}"
end

require 'net/http'
require 'jwt'

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
      algorithm: ['RS256'],
      iss: "#{AppSettings::IDENTITY_BASE_URL}/",
      verify_iss: true,
      aud:,
      verify_aud: true,
      jwks: { keys: get_jwks[:keys] }
    }

    JWT.decode(token, nil, true, options)
  end

  def get_jwks
    Rails.cache.fetch('well_known_jwks', expires_in: 12.hours) do
      jwks_uri = URI("#{AppSettings::IDENTITY_BASE_URL}/.well-known/jwks.json")
      jwks_response = Net::HTTP.get_response jwks_uri
      JSON.parse(jwks_response.body).deep_symbolize_keys
    end
  end

  def validate_token(token, audience = nil)
    jwks_response = get_jwks

    if jwks_response[:keys].blank?
      error = Error.new(message: 'Unable to verify credentials', status: :internal_server_error)
      return Response.new(nil, error)
    end

    decoded_token = decode_token(token, audience)

    Response.new(decoded_token, nil)
  rescue JWT::DecodeError
    error = Error.new('Bad credentials', :unauthorized)
    Response.new(nil, error)
  end

  def from_hash(hash) = OAuth2::AccessToken.from_hash(oauth2_client, hash)

  def authorize_url(redirect_host:)
    redirect_uri = "#{redirect_host}/oauth2/callback"
    oauth2_client.auth_code.authorize_url(redirect_uri:)
  end

  def oauth2_client
    @oauth2_client ||= OAuth2::Client.new(
      AppSettings::Oauth::CLIENT_ID,
      AppSettings::Oauth::CLIENT_SECRET,
      site: AppSettings::IDENTITY_BASE_URL,
      authorize_url: '/authorize',
      token_url: '/token'
    )
  end

  def client_access_token(audience_key)
    oauth2_client
      .client_credentials
      .get_token(
        audience: platform_audience(audience_key, :app_id)
      )
  end

  def bearer_access_token(audience_key) = "Bearer #{client_access_token(audience_key).token}"
end
class AuthenticationController < ApplicationController
  def callback
    redirect_host = request.protocol + request.host_with_port
    access_token = IdentityClient.oauth2_client.auth_code.get_token(params[:code], redirect_uri: "#{redirect_host}/oauth2/callback")
    access_token_payload, _header = IdentityClient.decode_token(access_token.token)
    session[:user_id] = access_token_payload['sub']

    JwtCache.write_access_token(session[:user_id], access_token)
    redirect_to root_url
  rescue OAuth2::Error, JWT::DecodeError
    render plain: 'Bad credentials'
  end

  def logout
    reset_session

    redirect_to root_url
  end
end
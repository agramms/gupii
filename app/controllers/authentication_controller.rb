class AuthenticationController < ApplicationController
  def authorize
    redirect_host = request.protocol + request.host_with_port
    # Handle subpath deployment - use the script name from nginx proxy headers
    subpath = request.headers['X-Script-Name'] || ''
    
    authorization_url = IdentityClient.authorize_url(redirect_host: redirect_host, subpath: subpath)
    redirect_to authorization_url, allow_other_host: true
  end

  def callback
    redirect_host = request.protocol + request.host_with_port
    # Handle subpath deployment - use the script name from nginx proxy headers
    subpath = request.headers['X-Script-Name'] || ''
    callback_url = "#{redirect_host}#{subpath}/oauth2/callback"
    
    access_token = IdentityClient.oauth2_client.auth_code.get_token(params[:code], redirect_uri: callback_url)
    access_token_payload, _header = IdentityClient.decode_token(access_token.token)
    session[:user_id] = access_token_payload['sub']

    JwtCache.write_access_token(session[:user_id], access_token)
    redirect_to root_url
  rescue OAuth2::Error, JWT::DecodeError
    render plain: 'Bad credentials'
  end

  def logout
    # Clear user-specific cached data
    if session[:user_id]
      Rails.cache.delete("#{session[:user_id]}/access_token_hash")
      Rails.cache.delete("#{session[:user_id]}/workspaces")
    end
    
    reset_session
    redirect_to root_url
  end
end
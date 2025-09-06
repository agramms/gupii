require 'oauth2'

class AuthBaseController < ApplicationController
  before_action :authenticated
  before_action :refresh_auth_vars
  rescue_from OAuth2::Error, with: :handle_oauth2_errors

  private

  CONSOLE_WORKSPACES_URL = 'https://api.console.iugu.com/workspaces'.freeze

  def read_access_token = JwtCache.read_access_token(session[:user_id])

  def refresh_auth_vars
    @current_user = session[:user_id]
    access_token = read_access_token
    return unless access_token

    workspaces = JSON.parse(access_token.get(CONSOLE_WORKSPACES_URL).body)

    @current_workspace = workspaces['current']
    @current_workspace_name = workspaces['workspaces'].find { |d| d['id'] == workspaces['current'] }['name']
  end

  def handle_oauth2_errors(exception)
    if exception.code == 'Expired JWT'
      redirect_user_to_auth
      return false
    end
    raise exception
  end

  def redirect_user_to_auth
    redirect_host = request.protocol + request.host_with_port

    redirect_uri = "#{redirect_host}/oauth2/callback"
    authorization_url = IdentityClient.oauth2_client.auth_code.authorize_url(redirect_uri:)
    redirect_to authorization_url, allow_other_host: true
  end

  def logged?
    access_token = read_access_token

    return false if access_token.nil? || access_token.expired?

    begin
      new_access_token = access_token.refresh!

      return false if IdentityClient.validate_token(new_access_token.token).error.present?

      JwtCache.write_access_token(session[:user_id], new_access_token)
      true
    rescue OAuth2::Error
      false
    end
  end

  def authenticated
    return if Rails.env.test? || logged?

    redirect_user_to_auth
  end
end
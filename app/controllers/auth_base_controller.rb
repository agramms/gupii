require 'oauth2'
require 'ostruct'

class AuthBaseController < ApplicationController
  before_action :authenticated
  before_action :refresh_auth_vars
  rescue_from OAuth2::Error, with: :handle_oauth2_errors
  
  helper_method :current_user

  private

  CONSOLE_WORKSPACES_URL = 'https://api.console.iugu.com/workspaces'.freeze

  def read_access_token = JwtCache.read_access_token(session[:user_id])

  def current_user
    return @current_user_object if defined?(@current_user_object)
    
    user_id = session[:user_id]
    return nil unless user_id
    
    access_token = read_access_token
    return nil unless access_token
    
    # Create a simple user object with essential info
    @current_user_object = OpenStruct.new(
      id: user_id,
      email: user_id # In this system, user_id appears to be the email
    )
  end

  def refresh_auth_vars
    @current_user = session[:user_id]
    return unless @current_user
    
    access_token = read_access_token
    return unless access_token

    # Cache workspace information to avoid API calls on every request
    workspaces = Rails.cache.fetch("#{@current_user}/workspaces", expires_in: 30.minutes) do
      begin
        JSON.parse(access_token.get(CONSOLE_WORKSPACES_URL).body)
      rescue OAuth2::Error => e
        # If token is expired, let the main authentication flow handle it
        raise e if e.code == 'Expired JWT'
        # For other errors, return empty workspaces to avoid blocking the request
        Rails.logger.error "[AuthBaseController] Failed to fetch workspaces: #{e.message}"
        { 'current' => nil, 'workspaces' => [] }
      end
    end

    @current_workspace = workspaces['current']
    @current_workspace_name = workspaces['workspaces'].find { |d| d['id'] == workspaces['current'] }&.dig('name')
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
    puts "🚨 AUTH DEBUG: redirect_host=#{redirect_host.inspect}, request.url=#{request.url.inspect}"
    
    authorization_url = IdentityClient.authorize_url(redirect_host: redirect_host)
    puts "🚨 AUTH DEBUG: authorization_url=#{authorization_url.inspect}"
    redirect_to authorization_url, allow_other_host: true
  end

  def logged?
    access_token = read_access_token
    return false if access_token.nil?

    # If token is not expired, we're good to go
    return true unless access_token.expired?

    # Only refresh if token is expired
    begin
      new_access_token = access_token.refresh!
      
      # Store the refreshed token
      JwtCache.write_access_token(session[:user_id], new_access_token)
      
      # Clear workspace cache when token is refreshed to ensure fresh data
      Rails.cache.delete("#{session[:user_id]}/workspaces")
      
      true
    rescue OAuth2::Error => e
      Rails.logger.info "[AuthBaseController] Token refresh failed: #{e.message}"
      false
    end
  end

  def authenticated
    return if Rails.env.test? || logged?

    redirect_user_to_auth
  end
end
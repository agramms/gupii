# frozen_string_literal: true

class AuthTestController < AuthBaseController
  def show
    render json: {
      authenticated: logged?,
      user_id: session[:user_id],
      has_access_token: JwtCache.read_access_token(session[:user_id]).present?,
      current_user_present: current_user.present?,
    }
  end
end

# frozen_string_literal: true

class AuthTestController < AuthBaseController
  def show
    user_id = session[:user_id]
    access_token = user_id ? JwtCache.read_access_token(user_id) : nil

    render json: {
      authenticated: logged?,
      user_id: user_id,
      has_access_token: access_token.present?,
      current_user_present: current_user.present?,
    }
  end
end

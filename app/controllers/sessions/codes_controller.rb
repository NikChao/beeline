class Sessions::CodesController < ApplicationController
  allow_unauthenticated_access
  rate_limit to: 10, within: 10.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Too many tries. Ask for a new code in a few minutes." }

  before_action :set_email_address

  def new
  end

  def create
    user = User.find_by(email_address: @email_address)

    if user&.redeem_sign_in_code(params[:code])
      session.delete(:pending_email_address)
      start_new_session_for user
      refresh_or_redirect_to after_authentication_url # the app reloads the page that asked
    else
      flash.now[:alert] = "That code didn't work. Check it, or ask for a new one."
      render :new, status: :unprocessable_entity
    end
  end

  private
    def set_email_address
      @email_address = session[:pending_email_address] or redirect_to new_session_path
    end
end

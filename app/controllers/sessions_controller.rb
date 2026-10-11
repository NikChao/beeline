class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 10.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "That's a lot of codes. Try again in a few minutes." }

  def new
  end

  # Sent while you wait, so a refused address is said out loud rather than a
  # code that never comes. Something that isn't an address goes on regardless.
  def create
    if (user = User.for_sign_in(params[:email_address])) && !user.sign_in_code_just_sent?
      SessionMailer.sign_in_code(user, user.issue_sign_in_code).deliver_now
    end

    session[:pending_email_address] = User.normalize_value_for(:email_address, params[:email_address].to_s)
    redirect_to new_session_code_path
  rescue Net::SMTPError, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError => error
    Rails.logger.error "Couldn't send a sign-in code: #{error.class}: #{error.message}"
    redirect_to new_session_path, alert: "Beeline couldn't email a code to that address. Check it, or try again later."
  end

  def destroy
    terminate_session
    redirect_to root_path
  end
end

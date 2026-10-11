class SessionMailer < ApplicationMailer
  def sign_in_code(user, code)
    @code = code
    mail to: user.email_address, subject: "#{code} is your Beeline code"
  end
end

class ApplicationMailer < ActionMailer::Base
  # Resend's shared sender works without a domain of your own, but only
  # delivers to the address your Resend account was made with.
  default from: ENV.fetch("BEELINE_MAIL_FROM", "Beeline <onboarding@resend.dev>")
  layout "mailer"
end

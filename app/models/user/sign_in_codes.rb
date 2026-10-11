# Six-digit codes, emailed on request. Each lasts a few minutes, allows a few
# tries, and is stored only as a digest. Asking for a new one voids the last.
module User::SignInCodes
  extend ActiveSupport::Concern

  included do
    has_many :sign_in_codes, dependent: :delete_all
  end

  def issue_sign_in_code
    code = format("%06d", SecureRandom.random_number(1_000_000))

    transaction do
      sign_in_codes.delete_all
      sign_in_codes.create!(code: code, expires_at: SignInCode::LIFETIME.from_now)
    end

    code
  end

  # A second ask moments after the first (a double click, say) would cancel
  # the code that's already on its way, so it's ignored.
  def sign_in_code_just_sent?
    sign_in_codes.usable.where(created_at: 30.seconds.ago..).exists?
  end

  def redeem_sign_in_code(code)
    sign_in_code = sign_in_codes.usable.last or return false
    sign_in_code.increment!(:attempts)

    if sign_in_code.authenticate_code(code.to_s.gsub(/\D/, ""))
      sign_in_codes.delete_all
      true
    else
      false
    end
  end
end

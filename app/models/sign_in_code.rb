class SignInCode < ApplicationRecord
  LIFETIME = 3.hours
  MAX_ATTEMPTS = 5

  belongs_to :user
  has_secure_password :code, validations: false

  scope :usable, -> { where(expires_at: Time.current..).where(attempts: ...MAX_ATTEMPTS) }
end

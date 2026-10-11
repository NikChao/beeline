class User < ApplicationRecord
  include SignInCodes

  has_many :sessions, dependent: :destroy
  has_many :papers, dependent: :destroy

  normalizes :email_address, with: -> { it.strip.downcase }
  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  # Anyone with an email address can sign in; asking for a first code makes the
  # account. Nil if it isn't an email address.
  def self.for_sign_in(email_address)
    user = find_or_create_by(email_address: normalize_value_for(:email_address, email_address.to_s))
    user if user.persisted?
  end
end

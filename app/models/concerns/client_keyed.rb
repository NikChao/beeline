# Records saved from the offline outbox carry the key the client made for them,
# so a save that's replayed after a lost response finds the original.
module ClientKeyed
  extend ActiveSupport::Concern

  class_methods do
    def saved_with(client_key)
      find_by(client_key: client_key) if client_key.present?
    end
  end
end

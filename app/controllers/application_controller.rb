class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    # Sent with every save from the offline outbox; see ClientKeyed.
    def client_key
      request.headers["Idempotency-Key"].presence
    end
end

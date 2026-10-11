# Sign-in, in prod mode (BEELINE_MODE=prod). In local mode, Beeline
# is open to whoever can reach it, as on a home network.
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication, if: :authentication_required?
    helper_method :authentication_required?, :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authentication_required?
      Rails.configuration.x.authentication
    end

    def authenticated?
      resume_session.present?
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id]) if cookies.signed[:session_id]
    end

    # The outbox and the app can't follow a redirect to a form: tell them, and
    # they'll keep their saves and ask to sign in.
    def request_authentication
      if client_key || hotwire_native_app?
        head :unauthorized
      else
        session[:return_to_after_authenticating] = request.url
        redirect_to new_session_path
      end
    end

    # The papers this person can work on: their own when signing in is on,
    # all of them on a local server, where there are no accounts.
    def writable_papers
      authentication_required? ? Current.user.papers : Paper.all
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || papers_url
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session&.destroy
      cookies.delete(:session_id)
    end
end

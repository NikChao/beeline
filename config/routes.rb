Rails.application.routes.draw do
  # One address: www.beeline.ink redirects to beeline.ink (BEELINE_HOST).
  constraints(->(request) { request.host == "www.#{Rails.configuration.x.host}" }) do
    match "(*path)", to: redirect { |_, request| request.url.sub("://www.", "://") }, via: :all
  end

  # In prod, Beeline opens on the landing page; locally, straight to the desk.
  root Rails.configuration.x.landing ? "landings#show" : "papers#index"

  resource :landing, only: :show
  resource :shelf, only: :show

  resource :session, only: %i[ new create destroy ] do
    scope module: :sessions do
      resource :code, only: %i[ new create ]
    end
  end
  resource :outbox, only: :show

  resources :papers, only: %i[ index show new create destroy ] do
    scope module: :papers do
      resource :publication, only: %i[ create destroy ]

      resources :drafts, only: %i[ show new create ] do
        scope module: :drafts do
          resources :marks, only: %i[ create destroy ]
        end
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
  get "configurations/ios_v1" => "configurations#ios_v1", as: :ios_configuration
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end

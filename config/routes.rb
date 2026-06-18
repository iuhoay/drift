Rails.application.routes.draw do
  resource :session, only: [ :new, :create, :destroy ]
  resource :registration, only: [ :new, :create ]
  resources :passwords, param: :token, only: [ :new, :create, :edit, :update ]

  # Email confirmation: :show verifies a signed link (works signed-out),
  # :create resends to the signed-in user.
  resources :email_verifications, only: [ :show, :create ], param: :token

  # Third-party sign-in. OmniAuth's middleware handles the POST /auth/:provider
  # request phase; the app only owns the callback and failure endpoints.
  get "auth/:provider/callback", to: "sessions/omniauth#create", as: :omniauth_callback
  get "auth/failure", to: "sessions/omniauth#failure"

  # Account self-service.
  resource :account, only: [ :show, :destroy ]
  namespace :account do
    resource :email, only: [ :edit, :update ]
    resource :password, only: [ :edit, :update ]
    delete "sessions/others", to: "sessions#destroy_others", as: :other_sessions
    resources :sessions, only: [ :index, :destroy ]
    resources :identities, only: [ :destroy ]
    resources :api_tokens, only: [ :index, :create, :destroy ]
  end

  # WebSub (PubSubHubbub) push: the hub confirms intent via GET (echo hub.challenge)
  # and delivers feed updates via POST. See WebSub::CallbacksController.
  get  "web_sub/callbacks/:token" => "web_sub/callbacks#verify", as: :web_sub_callback
  post "web_sub/callbacks/:token" => "web_sub/callbacks#receive"

  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "offline" => "pwa#offline", as: :pwa_offline

  # Self-hosted performance monitoring dashboard (admin-only; see config/initializers/rails_pulse.rb)
  mount RailsPulse::Engine => "/rails_pulse"

  # Background job dashboard (admin-only; see config/initializers/mission_control.rb)
  mount MissionControl::Jobs::Engine, at: "/jobs"

  # First-party admin landing page (front door to the mounted dashboards above).
  namespace :admin do
    root "dashboard#show"
    resources :web_sub_subscriptions, only: :index
  end

  # Static pages — readable without an account (linked from sign-in / sign-up).
  get "about" => "pages#about", as: :about
  get "terms" => "pages#terms", as: :terms
  get "privacy" => "pages#privacy", as: :privacy

  resource :theme, only: :update
  resource :activity, only: :show

  resources :subscriptions, only: [ :index, :new, :create, :update, :destroy ]

  resources :entries, only: [ :index, :show ] do
    resource :read, only: [ :create, :destroy ], module: :entries
    resource :star, only: [ :create, :destroy ], module: :entries
  end

  # Read-it-later. The web UI (cookie auth) lists, reads, and removes saved
  # pages; the browser extension posts new ones to the token-authenticated API.
  resources :saved_items, only: [ :index, :show, :create, :destroy ] do
    resource :read, only: [ :create, :destroy ], module: :saved_items
    resource :star, only: [ :create, :destroy ], module: :saved_items
  end

  namespace :api do
    resources :saved_items, only: [ :create ]
  end

  root "entries#index"
end

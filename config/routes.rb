Rails.application.routes.draw do
  resource :session, only: [ :new, :create, :destroy ]
  resource :registration, only: [ :new, :create ]
  resources :passwords, param: :token, only: [ :new, :create, :edit, :update ]
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
  end

  resource :theme, only: :update
  resource :activity, only: :show

  resources :subscriptions, only: [ :index, :new, :create, :update, :destroy ]

  resources :entries, only: [ :index, :show ] do
    member do
      post :read
      post :unread
      post :star
      post :unstar
    end
  end

  root "entries#index"
end

Rails.application.routes.draw do
  resource :session, only: [ :new, :create, :destroy ]
  resource :registration, only: [ :new, :create ]
  resources :passwords, param: :token, only: [ :new, :create, :edit, :update ]
  get "up" => "rails/health#show", as: :rails_health_check

  resource :theme, only: :update

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

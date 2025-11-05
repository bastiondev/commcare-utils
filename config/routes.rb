Rails.application.routes.draw do
  passwordless_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Good Job console for logged in users
  mount GoodJob::Engine => 'queue', constraints: UserConstraint.new

  namespace :api do
    post '/forwarding', to: 'data_forwarding#create'
  end

  resources :destinations do
    member do
      post :create_token, to: 'destinations#create_token'
      post :delete_token, to: 'destinations#delete_token'
    end
    resources :destination_sources
  end

  resources :users

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"
end

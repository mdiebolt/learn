Rails.application.routes.draw do
  resource :session
  resource :preferences
  resources :passwords, param: :token
  resources :registrations

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  # get "offline" => "rails/pwa#offline", as: :pwa_offline

  resources :audiobooks do
    resource :transcription, module: :audiobook
  end

  resources :chapters do
    resource :progress, module: :chapter
    resource :study_guide
  end

  resources :cards do
    resources :reviews, module: :card
  end

  resources :due_cards

  root "audiobooks#index"
end

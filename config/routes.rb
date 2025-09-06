Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Root route
  root "admin/dashboard#index"

  # Admin UI routes
  namespace :admin do
    root "dashboard#index"
    
    # PIX Key Management
    resources :pix_keys
    
    # Infraction Reports
    resources :infraction_reports
    
    # Transaction Refunds
    resources :transaction_refunds
  end

  # API routes for client applications
  namespace :api do
    namespace :v1 do
      # Polling endpoint for client updates
      get "events/poll", to: "events#poll"
      
      # PIX operations
      resources :pix_operations, only: [:create, :show, :index]
      
      # Health check
      get "health", to: "health#show"
    end
  end
end

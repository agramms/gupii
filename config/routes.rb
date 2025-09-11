Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # OAuth2 Authentication routes
  get "authorize", to: "authentication#authorize"
  get "oauth2/callback", to: "authentication#callback"
  get "logout", to: "authentication#logout"

  # Root route - Dashboard
  root "dashboard#index"
  
  # Web UI routes
  # Dashboard (Home)
  resources :dashboard, only: [:index]
  
  # PIX Key Management
  resources :pix_keys
  
  # Infraction Notifications Management
  resources :infraction_notifications, except: [:destroy, :edit, :update] do
    member do
      patch :cancel
    end
    # Nested dispute creation from infraction notifications
    resources :disputes, only: [:new, :create]
  end
  
  # Disputes Management (standalone routes)
  resources :disputes, except: [:destroy, :edit, :update, :new, :create] do
    member do
      patch :approve
      patch :reject  
      patch :escalate
      patch :assign
      patch :cancel
    end
    collection do
      post :auto_decline_overdue
    end
  end
  
  # Payment Service Providers Management (Read-only)
  resources :payment_service_providers, only: [:index, :show] do
    collection do
      post :sync
      get :sync_status
      get :metrics
      get :health
    end
  end

  # API routes for client applications
  namespace :api do
    namespace :v1 do
      # Polling endpoint for client updates
      get "events/poll", to: "events#poll"
      
      # PIX operations
      resources :pix_operations, only: [:create, :show, :index]
      
      # Infraction Notifications API
      resources :infraction_notifications, except: [:destroy, :edit, :update] do
        member do
          patch :cancel
        end
      end
      
      # Disputes API
      resources :disputes, except: [:destroy, :edit, :update] do
        member do
          patch :approve
          patch :reject  
          patch :escalate
          patch :assign
        end
        collection do
          post :auto_decline_overdue
          get :overdue
          get :approaching_deadline
          get :stats
        end
      end
      
      # Payment Service Providers API (Read-only)
      resources :payment_service_providers, only: [:index, :show] do
        collection do
          get :search
          get :active
          get :pix_enabled
          get :stats
          get "by_ispb/:ispb", to: "payment_service_providers#by_ispb", as: :by_ispb
        end
      end
      
      # Health check
      get "health", to: "health#show"
    end
  end
end

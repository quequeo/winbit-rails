Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: 'users/omniauth_callbacks',
    sessions: 'users/sessions'
  }

  namespace :api do
    namespace :public do
      get 'investor/*email/history', to: 'investors#history', format: false
      get 'investor/*email', to: 'investors#show', format: false
      get 'wallets', to: 'wallets#index', format: false
      post 'requests', to: 'requests#create', format: false
    end

    namespace :admin do
      get 'session', to: 'session#show', format: false
      get 'dashboard', to: 'dashboard#show', format: false

      resources :investors, only: [:index, :show, :create, :update, :destroy], format: false do
        post 'toggle_status', on: :member
      end

      get 'portfolios', to: 'portfolios#index', format: false
      patch 'portfolios/:id', to: 'portfolios#update', format: false

      get 'requests', to: 'requests_list#index', format: false
      post 'requests', to: 'requests#create', format: false
      patch 'requests/:id', to: 'requests#update', format: false
      delete 'requests/:id', to: 'requests#destroy', format: false
      post 'requests/:id/approve', to: 'requests#approve', format: false
      post 'requests/:id/reject', to: 'requests#reject', format: false

      resources :admins, only: [:index, :create, :update, :destroy], format: false

      get 'settings', to: 'settings#index', format: false
      patch 'settings', to: 'settings#update', format: false

      get 'activity_logs', to: 'activity_logs#index', format: false
    end
  end

  # Serve the Vite SPA (built into /public) from Rails in production.
  root to: 'spa#index'
  get '*path', to: 'spa#index', constraints: lambda { |req|
    !req.path.start_with?('/api') &&
      !req.path.start_with?('/users') &&
      !req.path.start_with?('/rails')
  }
end

Rails.application.routes.draw do
  namespace :api do
    resources :routes, only: [:index, :show] do
      resources :trips, only: [:show]
    end
    resources :stops, only: [:index, :show]
  end
  get '/about', to: 'index#index'
  get '/trains(/*id)', to: 'index#index'
  get '/stations(/*id)', to: 'index#index'
  root 'index#index'
end

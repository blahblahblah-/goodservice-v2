Rails.application.routes.draw do
  namespace :api do
    resources :routes, only: [:index, :show]
  end
  get '/trains(/*id)', to: 'index#index'
  root 'index#index'
end

Rails.application.routes.draw do
  namespace :api do
    resources :ios_versions, only: [:index], :path => '/ios-versions'
    resources :routes, only: [:index, :show] do
      resources :trips, only: [:show]
    end
    resources :stops, only: [:index, :show]
    post '/slack', to: 'slack#index'
    post '/slack/query', to: 'slack#query'
    post '/alexa', to: 'alexa#index'
  end
  get '/about', to: 'index#index'
  get '/twitter', to: 'index#index'
  get '/trains(/*id)', to: 'index#index'
  get '/stations(/*id)', to: 'index#index'
  get '/oauth', to: 'oauth#index'
  get '/slack', to: 'slack#index'
  get '/slack/help', to: 'slack#help'
  get '/slack/privacy', to: 'slack#privacy'
  get '/slack/install', to: 'oauth#slack_install'
  root 'index#index'
end

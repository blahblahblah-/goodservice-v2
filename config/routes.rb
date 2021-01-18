Rails.application.routes.draw do
  namespace :api do
    resources :info, only: [:index]
    resources :routes, only: [:show]
  end
end

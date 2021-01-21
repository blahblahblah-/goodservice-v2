Rails.application.routes.draw do
  namespace :api do
    resources :routes, only: [:index, :show]
  end

  root 'index#index'
end

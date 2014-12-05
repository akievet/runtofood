Rails.application.routes.draw do
  resources :routes, only: [:index]
end

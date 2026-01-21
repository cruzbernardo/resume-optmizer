Rails.application.routes.draw do
  get "llm/submit", to: "llm#submit"
  post "llm/submit", to: "llm#create"
  get "llm/show", to: "llm#show"
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Health check with Redis status
  get "health", to: "health#show"
  get "health/rate_limits", to: "health#rate_limits"
  get "health/llm_rate_limits", to: "health#llm_rate_limits"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "pages#home"
end

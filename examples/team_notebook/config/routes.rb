Rails.application.routes.draw do
  root "teams#index"
  post "demo/session", to: "demo_sessions#create", as: :demo_session
  resources :teams, only: [] do
    resources :articles
  end
end

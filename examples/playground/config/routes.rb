Rails.application.routes.draw do
  root "policy_comparisons#show"
  get "/shipping", to: "playground#show", as: :shipping
  post "/compare", to: "playground#compare", as: :compare
  get "up" => "rails/health#show", as: :rails_health_check
end

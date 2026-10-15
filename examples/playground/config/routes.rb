Rails.application.routes.draw do
  root "playground#show"
  post "/compare", to: "playground#compare", as: :compare
  get "up" => "rails/health#show", as: :rails_health_check
end

Rails.application.routes.draw do
  root "imports#new"

  post "/imports/preview", to: "imports#preview"
  post "/imports/create", to: "imports#create"
end

Rails.application.routes.draw do
  root 'hello#index'
  post 'callback' => 'line_bot#callback'
end

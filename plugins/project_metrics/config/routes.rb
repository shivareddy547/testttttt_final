# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
# match '/metrics/index', :to => 'metrics#index', :via => [:get, :post]

# match '/projects/:project_id/metrics', :to => 'metrics#index', :via => [:get, :post]

resources :projects do
  resources :metrics, :only => [:index]
end
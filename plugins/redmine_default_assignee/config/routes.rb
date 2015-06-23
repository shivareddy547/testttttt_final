# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
match '/default_assignee_setup/index', :to => 'default_assignee_setup#index', :via => [:get, :post]
match '/default_assignee_setup/result', :to => 'default_assignee_setup#result', :via => [:get, :post]

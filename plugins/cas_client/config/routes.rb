# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
get 'token', :to => 'cas_token#index'
post 'token', :to => 'cas_token#index'
# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
get 'check_token', :to => 'cas_token#check_token'
post 'check_token', :to => 'cas_token#check_token'
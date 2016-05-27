# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html


match 'services/ptos/request', :to => 'inia_service#create_ptos', :via => [:post]
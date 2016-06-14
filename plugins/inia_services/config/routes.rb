# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html


match 'services/ptos/request', :to => 'inia_service#create_ptos', :via => [:post]
match 'services/ptos/auto_approve', :to => 'inia_service#update_auto_unapproved_entries', :via => [:post]

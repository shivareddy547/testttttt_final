# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
match '/timelog_importer/index', :to => 'timelog_import#index', :via => [:get, :post]
match '/timelog_importer/match', :to => 'timelog_import#match', :via => [:get, :post]
match '/timelog_importer/result', :to => 'timelog_import#result', :via => [:get, :post]
match '/timelog_importer/export_csv', :to => 'timelog_import#export_csv', :via => [:get, :post]
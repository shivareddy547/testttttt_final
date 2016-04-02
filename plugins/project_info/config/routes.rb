# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
match '/projects_locations', :to => 'project_location_setup#locations_list', :as => 'projects_location_list', :via => [:get]

match '/projects_locations/new', :to => 'project_location_setup#new', :as => 'projects_location_new', :via => [:get]
match '/projects_locations/edit', :to => 'project_location_setup#edit', :as => 'projects_location_edit', :via => [:get]
match '/projects_locations/create', :to => 'project_location_setup#create', :as => 'projects_location_edit', :via => [:post]
match '/projects_locations/update', :to => 'project_location_setup#update', :as => 'projects_location_update', :via => [:put,:post]
match '/projects_locations/delete', :to => 'project_location_setup#destroy', :as => 'projects_location_delete', :via => [:get,:delete]
match '/get_project_locations', :to => 'project_location_setup#get_project_locations', :as => 'get_project_locations', :via => [:post]


match '/projects_regions', :to => 'project_region_setup#regions_list', :as => 'projects_region_list', :via => [:get]
match '/projects_regions/new', :to => 'project_region_setup#new', :as => 'projects_region_new', :via => [:get]
match '/projects_regions/edit', :to => 'project_region_setup#edit', :as => 'projects_region_edit', :via => [:get]
match '/projects_regions/create', :to => 'project_region_setup#create', :as => 'projects_region_edit', :via => [:post]
match '/projects_regions/update', :to => 'project_region_setup#update', :as => 'projects_region_update', :via => [:put,:post]
match '/projects_regions/delete', :to => 'project_region_setup#destroy', :as => 'projects_region_delete', :via => [:delete]

match '/services/append_members', :to => 'services#append_members', :as => 'append_members', :via => [:post,:get]
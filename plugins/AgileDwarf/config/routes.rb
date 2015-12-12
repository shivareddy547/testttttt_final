if Rails::VERSION::MAJOR < 3
  ActionController::Routing::Routes.draw do |map|
    map.connect 'adburndown/:action/:id', :controller => :adburndown
    map.connect 'adsprintinl/:action/:id', :controller => :adsprintinl
    map.connect 'adsprints/:action/:id', :controller => :adsprints
    map.connect 'adtaskinl/:action/:id', :controller => :adtaskinl
    map.connect 'adtasks/:action/:id', :controller => :adtasks
  end
else
  match 'adburndown/(:action(/:id))', :controller => 'adburndown'
  match 'adsprintinl/(:action(/:id))', :controller => 'adsprintinl'
  match 'adsprints/(:action(/:id))', :controller => 'adsprints'
  match 'adtaskinl/(:action(/:id))', :controller => 'adtaskinl'
  match 'adtasks/(:action(/:id))', :controller => 'adtasks'

  match 'adsprints/add_issue_to_sprint', :controller => 'adsprints', :action => "add_issue_to_sprint",:via => [:get,:post]
  match 'adsprints/create_issue_to_sprint', :controller => 'adsprints', :action => "create_issue_to_sprint",:via => [:get,:post]
  match 'adsprints/new', :controller => 'adsprints', :action => "new",:via => [:get,:post]
  match 'adsprints/edit', :controller => 'adsprints', :action => "edit",:via => [:get,:post]
  match 'adsprints/create_sprint', :controller => 'adsprints', :action => "create_sprint",:via => [:get,:post]
  match 'adsprints/update_sprint', :controller => 'adsprints', :action => "update_sprint",:via => [:get,:post]

end
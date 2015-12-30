# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
match 'employee_info/get_capacity_details_of_other_project', :controller => 'employee_info', :action => "get_capacity_details_of_other_project",:via => [:get,:post]
# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
match '/reject_locked_reports/index', :to => 'reject_locked_reports#index', :via => [:get, :post]
match '/reject_locked_reports/result', :to => 'reject_locked_reports#result', :via => [:get, :post]
match '/reject_locked_reports/unlocked_report', :to => 'reject_locked_reports#unlocked_report', :via => [:get, :post]
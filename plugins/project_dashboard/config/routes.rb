# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html


get '/dashboard/get_version_id', to: 'dashboard#get_version_id'
get '/dashboard/index', to: 'dashboard#index'
get '/dashboard/page_layout', to: 'dashboard#page_layout'
get '/dashboard/page', to: 'dashboard#page'
post '/dashboard/add_block', to: 'dashboard#add_block'
post '/dashboard/remove_block', to: 'dashboard#remove_block'
post '/dashboard/order_blocks', to: 'dashboard#order_blocks'
get '/dashboard/graphs_settings', to: 'dashboard#graphs_settings'
get '/dashboard/filter_query', to: 'dashboard#filter_query'
get '/dashboard/save_text_editor', to: 'dashboard#save_text_editor'

match '/dashboard/editor/preview/new/:project_id', :to => 'dashboard#preview_text_editor', :as => 'dashboard_preview_text_editor', :via => [:get, :post, :put]
# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

RedmineApp::Application.routes.draw do
	resources :projects do
		resources  :kanbans do
			resources :kanban_panes
			resources :kanban_workflow
		end
	end
	resource :kanban_card

	resources :trackers do
		resources :kanban_states
	end

	resources :kanban_stages

	match 'kanban_apis/kanban_card_journals', :controller => 'kanban_apis', :action => 'kanban_card_journals', :via => :get
	match 'kanban_apis/kanban_state_issue_status', :controller => 'kanban_apis', :action => 'kanban_state_issue_status', :via => :get
	match 'kanban_apis/kanban_workflow', :controller => 'kanban_apis', :action => 'kanban_workflow', :via => :get
	match 'kanban_apis/kanban_states', :controller => 'kanban_apis', :action => 'kanban_states', :via => :get
	match 'kanban_apis/close_issues', :controller => 'kanban_apis', :action => 'close_issues', :via => :put
	match 'project/:project_id/kanbans', :controller => 'kanbans', :action => 'index', :via => :get
	match 'kanban_apis/user_wip_and_limit', :controller => 'kanban_apis', :action => 'user_wip_and_limit', :via => :get
	match 'kanbans/setup', :controller => 'kanbans', :action => 'setup', :via => :get
	match 'kanban_states/setup', :controller=>'kanban_states', :action => 'setup', :via => :get
	match 'issue_status_kanban_states/update', :controller => 'issue_status_kanban_states', :action => "update", :via => :put
	match 'kanbans/copy', :controller => 'kanbans', :action => "copy"
	match 'kanban_reports/index', :controller => 'kanban_reports', :action => "index", :via => :get
	match 'kanban_apis/issue_card_detail', :controller => 'kanban_apis', :action => 'issue_card_detail', :via => :get
  get '/kanbans/filter_query', to: 'kanbans#filter_query'

  # match 'kanban_workflow/issue_card_setup', :controller => 'kanban_workflow', :action => "issue_card_setup"
  match 'kanban_cards/card_filelds_setup', :controller => 'kanban_cards', :action => "card_filelds_setup"
  match 'kanbans/kanban_issue_show', :controller => 'kanbans', :action => "kanban_issue_show",:via => [:get,:put,:post]
  match 'kanbans/find_kanban_state_id', :controller => 'kanbans', :action => "find_kanban_state_id",:via => [:get,:post]
  match 'kanbans/find_issue_status_id', :controller => 'kanbans', :action => "find_issue_status_id",:via => [:get,:post]
  match 'kanbans/update_form', :controller => 'kanbans', :action => "update_form",:as=>'kanban_issue_update_form',:via => [:get,:post]
  match 'kanban_cards/log_entry_new', :controller => 'kanban_cards', :action => "log_entry_new",:via => [:get,:post]
  match 'kanban_cards/log_entry_create', :controller => 'kanban_cards', :action => "log_entry_create",:via => [:get,:post]
	match 'kanban_cards/add_new_issue', :controller => 'kanban_cards', :action => "add_new_issue",:via => [:get,:post]
	match 'kanban_cards/create_new_issue', :controller => 'kanban_cards', :action => "create_new_issue",:via => [:get,:post]


end

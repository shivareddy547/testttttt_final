
require_dependency 'application_controller_patch'
RedmineApp::Application.config.after_initialize do
  require_dependency 'redmine_timelog_importer/infectors'
  #config.session_store :active_record_store
 # RedmineApp::Application.config.session_store :active_record_store
end
RedmineApp::Application.config.before_initialize do
  #RedmineApp::Application.config.session_store :active_record_store
end

ApplicationController.send(:include, ApplicationControllerPatch)

Redmine::Plugin.register :redmine_timelog_importer do
  name 'Redmine Time log Importer plugin'
  author 'OFS'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://ofmc.objectfrontier.com/'
  author_url 'http://ofmc.objectfrontier.com/'
 project_module :timelog_importer do
    permission :timelog_import, :timelog_import => :index
  end
  menu :project_menu, :timelog_importer, { :controller => 'timelog_import', :action => 'index' }, :caption => :label_import_time_log, :before => :settings, :param => :project_id
  RedmineApp::Application.config.session_store :active_record_store
end

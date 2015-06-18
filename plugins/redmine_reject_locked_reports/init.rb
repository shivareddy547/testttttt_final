
RedmineApp::Application.config.after_initialize do
  require_dependency 'application_helper_patch'
  #config.session_store :active_record_store
  # RedmineApp::Application.config.session_store :active_record_store
end
Rails.configuration.to_prepare do
  require_dependency 'application_helper_patch'
  require_dependency 'reject_locked_reports_helper'
end

ApplicationHelper.send(:include, ApplicationHelperPatch)


Redmine::Plugin.register :redmine_reject_locked_reports do
  name 'Redmine Default Assignee plugin'
  author 'OFS'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://ofmc.objectfrontier.com/'
  author_url 'http://ofmc.objectfrontier.com/'

  project_module :reject_locked_reports do
    permission :reject_locked_reports, :reject_locked_reports => :index
    permission :result,  {:reject_locked_reports => [:result]},:public => true
    permission :unlocked_report,  {:reject_locked_reports => [:unlocked_report]},:public => true
  end
  menu :project_menu , :reject_locked_reports, { :controller => 'reject_locked_reports', :action => 'index' }, :caption => :lable_reject_locked_report, :before => :settings, :param => :project_id

end

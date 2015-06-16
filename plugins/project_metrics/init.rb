# encoding: UTF-8
require 'redmine'
Mime::Type.register "application/xls", :xls


RedmineApp::Application.config.after_initialize do
  require_dependency 'project_metrics/infectors'
end



Redmine::Plugin.register :project_metrics do
  name 'Project Metrics plugin'
  author 'OFS'
  description 'This is a plugin for Redmine'
  version '0.0.1'

  project_module :metrics do
    permission :metrics, :metrics => :index
  end
  menu :project_menu, :metrics, { :controller => 'metrics', :action => 'index' }, :caption => :label_metrics, :before => :settings, :param => :project_id
end

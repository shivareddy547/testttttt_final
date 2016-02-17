require 'redmine'
require 'redmine_importer/importer_issue_patch'

RedmineApp::Application.config.after_initialize do
   require_dependency 'redmine_importer/infectors'
end

# CustomFieldsHelper.send(:include, WktimeHelperPatch)
IssuesController.send(:include, IssuesControllerPatch)
Redmine::Plugin.register :redmine_importer do
  name 'Issue Importer'
  author 'Martin Liu / Leo Hourvitz / Stoyan Zhekov'
  description 'Issue import plugin for Redmine.'
  version '1.2'

  project_module :importer do
    permission :import, :importer => :index
  end
  menu :project_menu, :importer, { :controller => 'importer', :action => 'index' }, :caption => :label_import, :before => :settings, :param => :project_id

  Rails.configuration.to_prepare do
    unless Issue.included_modules.include?(RedmineImporter::Patches::ImporterIssuePatch)
      Issue.send(:include, RedmineImporter::Patches::ImporterIssuePatch)
    end


  end

end

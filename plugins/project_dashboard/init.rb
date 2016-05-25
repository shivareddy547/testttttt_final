require_dependency 'attachments_controller_patch'
require_dependency 'projects_controller_patch'
require_dependency 'previews_controller_patch'
require_dependency 'application_helper_patch'
require_dependency 'version_model_controller_patch'
RedmineApp::Application.config.after_initialize do
  require_dependency 'project_dashboard/infectors'
end

ProjectsController.send(:include, ProjectsControllerPatch)
AttachmentsController.send(:include, AttachmentsControllerPatch)
ApplicationHelper.send(:include, ApplicationHelperPatch)



Rails.configuration.to_prepare do

  unless Version.included_modules.include?(AgileDwarf::Patches::VersionPatch)
    Version.send(:include, AgileDwarf::Patches::VersionPatch)
  end
  unless VersionsController.included_modules.include?(AgileDwarf::Patches::VersionControllerPatch)
    VersionsController.send(:include, AgileDwarf::Patches::VersionControllerPatch)
  end
  # unless WikiPage.included_modules.include?(WikiChanges::Patches::WikiPagePatch)
  #   WikiPage.send(:include, WikiChanges::Patches::WikiPagePatch)
  # end
  # unless WikiPage.included_modules.include?(WikiChanges::Patches::WikiControllerPatch)
  #   WikiController.send(:include, WikiChanges::Patches::WikiControllerPatch)
  # end
  # unless WikiPage.included_modules.include?(WikiChanges::Patches::WikiPagePatch)
  #   WikiPage.send(:include, WikiChanges::Patches::WikiPagePatch)
  # end
end


Redmine::Plugin.register :project_dashboard do
  name 'Project Dashboard plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  project_module :project_dashboard do
    permission :dashboar_page_setup, :dashboard => :index
    permission :dashboar_page_layout_setup, :dashboard => :page_layout
    permission :dashboar_page, :dashboard => :page
    permission :dashboar_add_block, :dashboard => :add_block
    # permission :result,  {:default_assignee_setup => [:result]},:public => true
  end



end

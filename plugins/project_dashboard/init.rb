require_dependency 'attachments_controller_patch'
RedmineApp::Application.config.after_initialize do
  require_dependency 'project_dashboard/infectors'
end

ProjectsController.send(:include, ProjectsControllerPatch)
AttachmentsController.send(:include, AttachmentsControllerPatch)


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

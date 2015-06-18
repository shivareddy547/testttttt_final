require 'redmine'
# RedmineApp::Application.config.after_initialize do
#   require_dependency 'infectors'
# end
IssuesController.send(:include, IssuesControllerPatch)
Redmine::Plugin.register :code_refactor do
  name 'Code Refactor plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'
end

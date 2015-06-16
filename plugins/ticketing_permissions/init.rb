# Redmine::Plugin.register :ticketing_permissions do
#   name 'Ticketing Permissions plugin'
#   author 'Author name'
#   description 'This is a plugin for Redmine'
#   version '0.0.1'
#   url 'http://example.com/path/to/plugin'
#   author_url 'http://example.com/about'
# end
Redmine::Plugin.register :ticketing_permissions do
  name 'Ticketing Approval System'
  author 'OFS'
  description 'This is a plugin for iNia'
  version '0.0.1'
  url 'https://inia.objectfrontier.com/redmine'

  project_module :ticketing_permissions do
    #permission :manage_ticketing_approval,{ :controller => 'CategoryApprovalConfigsController' }, :require => :member
    # permission :set_assignee_for_approval,{ :controller => 'CategoryApprovalConfigsController', :action => 'set_assignee' }, :require => :member
    # project_module :approval_level do
      permission :a1, :require => :member
      permission :a2, :require => :member
      permission :a3, :require => :member
      permission :a4, :require => :member
      permission :a5, :require => :member
      permission :a6, :require => :member
      permission :a7, :require => :member
    # end
  end
end
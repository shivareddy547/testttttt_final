require 'wiki_changes/application_helper_patch'
Redmine::Plugin.register :wiki_changes do
  name 'Wiki Changes plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'


  project_module :wiki_permissions do |map|

    # permission :a16666, :require => :member
    # permission :a2, :require => :member
    # permission :a3, :require => :member
    # permission :a4, :require => :member
    #permission :manage_ticketing_approval,{ :controller => 'CategoryApprovalConfigsController' }, :require => :member
    # permission :set_assignee_for_approval,{ :controller => 'CategoryApprovalConfigsController', :action => 'set_assignee' }, :require => :member
    # project_module :approval_level do
    # map.permission :manage_wiki, {:wikis => [:edit, :destroy]}, :require => :member
    # map.permission :rename_wiki_pages, {:wiki => :rename}, :require => :member
    # map.permission :delete_wiki_pages, {:wiki => [:destroy, :destroy_version]}, :require => :member
    map.permission :view_wiki_pages, {:wiki => [:index, :show, :special, :date_index]}, :read => true
    # map.permission :export_wiki_pages, {:wiki => [:export]}, :read => true
    # map.permission :view_wiki_edits, {:wiki => [:history, :diff, :annotate]}, :read => true
    map.permission :edit_wiki_pages, :wiki => [:edit, :update, :preview, :add_attachment], :attachments => :upload
    map.permission :manage_wiki_pages_roles, :wiki => [:edit, :update, :preview, :add_attachment], :attachments => :upload
    # map.permission :delete_wiki_pages_attachments, {}
    # map.permission :protect_wiki_pages, {:wiki => :protect}, :require => :member
    # map.permission :edit_wiki_sections, :wiki => [:edit, :update, :preview, :add_attachment], :attachments => :upload
    # map.permission :view_wiki_pages, {:wiki => [:index, :show, :special, :date_index]}, :read => true
    # end
  end

  project_module :wiki do |map|
    map.permission :manage_wiki_pages_roles, :wiki => [:edit, :update, :preview, :add_attachment], :attachments => :upload
  end


end


Rails.configuration.to_prepare do

  unless ApplicationHelper.included_modules.include?(WikiChanges::Patches::ApplicationHelperPatch)
    ApplicationHelper.send(:include, WikiChanges::Patches::ApplicationHelperPatch)
  end
  unless WikiPage.included_modules.include?(WikiChanges::Patches::WikiPagePatch)
    WikiPage.send(:include, WikiChanges::Patches::WikiPagePatch)
  end
  unless WikiPage.included_modules.include?(WikiChanges::Patches::WikiControllerPatch)
    WikiController.send(:include, WikiChanges::Patches::WikiControllerPatch)
  end
  # unless WikiPage.included_modules.include?(WikiChanges::Patches::WikiPagePatch)
  #   WikiPage.send(:include, WikiChanges::Patches::WikiPagePatch)
  # end
end
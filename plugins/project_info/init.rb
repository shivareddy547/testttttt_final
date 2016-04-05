
require 'project_info/project_patch'
require 'projects_info_controller_patch'

require 'project_info/member_patch_for_history'
require 'project_info/role_patch'

Redmine::Plugin.register :project_info do
  name 'Project Info plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

  Redmine::MenuManager.map :admin_menu do |menu|
    menu.push :locations, {:controller => 'project_location_setup', :action => 'locations_list'}, :caption => "Locations"
    menu.push :regions, {:controller => 'project_region_setup', :action => 'regions_list'}, :caption => "Regions"

  end

  Rails.configuration.to_prepare do

    unless Project.included_modules.include? ProjectInfo::Patches::ProjectPatch
      Project.send(:include, ProjectInfo::Patches::ProjectPatch)
    end
    unless Member.included_modules.include? ProjectInfo::Patches::MemberPatchForHistory
      Member.send(:include, ProjectInfo::Patches::MemberPatchForHistory)
    end
    unless Role.included_modules.include? ProjectInfo::Patches::RolePatch
      Role.send(:include, ProjectInfo::Patches::RolePatch)
    end

    unless ProjectsController.included_modules.include? ProjectsInfoControllerPatch
      ProjectsController.send(:include,ProjectsInfoControllerPatch)
    end


  end

  ActionDispatch::Callbacks.to_prepare do
    require_dependency 'project_info/hooks'
    #require_dependency 'clipboard_image_paste/attachment_patch'
  end

end


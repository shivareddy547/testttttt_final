
require 'employee_info/user_patch'
require 'employee_info/member_patch'

UsersController.send(:include, UsersControllerPatch)
MembersController.send(:include, MembersControllerPatch)

Redmine::Plugin.register :employee_info do
  name 'Employee Info plugin'
  author 'OFS'
  description 'This is a plugin for iNia'
  version '0.0.1'
  url 'http://inia.objectfrontier.com'
  author_url 'http://inia.objectfrontier.com'

  project_module :hierarchy_permissions do
    permission :client_owner, :public => true
    permission :do, :public => true
    permission :co, :public => true
    # permission :developer, :public => true
  end

end


Rails.configuration.to_prepare do
 unless User.included_modules.include? EmployeeInfo::Patches::UserPatch
    User.send(:include, EmployeeInfo::Patches::UserPatch)
 end
 unless Group.included_modules.include? EmployeeInfo::GroupPatch
   Group.send(:include, EmployeeInfo::GroupPatch)
 end
 unless Member.included_modules.include? EmployeeInfo::Patches::MemberPatch
   Member.send(:include, EmployeeInfo::Patches::MemberPatch)
 end
 unless ApplicationHelper.included_modules.include?(EmployeeInfo::Patches::ApplicationHelperPatch)
   ApplicationHelper.send(:include, EmployeeInfo::Patches::ApplicationHelperPatch)
 end

end

ActionDispatch::Callbacks.to_prepare do
  require_dependency 'employee_info/hooks'
  #require_dependency 'clipboard_image_paste/attachment_patch'
end
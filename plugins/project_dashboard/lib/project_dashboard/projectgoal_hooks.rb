module ProjectDashboard
  module Hooks
  	class ProjectGoalSettingHook  < Redmine::Hook::ViewListener
      	def helper_projects_settings_tabs(context = {})
          #if User.current.allowed_to?(:new_tab_action, context[:project])
              context[:tabs].push({ :name    => 'project_goal',
                                    :action  => :setup,
                                    :partial => 'dashboard/blocks/project_goal_setup',
                                    :label   => :label_project_goal})
          #end
        end
 	  end


  end
end

module RedmineDefaultAssignee
 module ProjectsHelperPatch
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)
        base.class_eval do
            unloadable
            alias_method_chain :project_settings_tabs, :default_assignee
        end
      end

      module ClassMethods
      end

      module InstanceMethods
        def project_settings_tabs_with_default_assignee

          @tabs = project_settings_tabs_without_default_assignee
           # call_hook(:helper_projects_settings_tabs, { :tabs => tabs })
          find_project = Project.where(:identifier => params[:id])

          if find_project.present? && find_project.last.enabled_modules.map(&:name).include?("default_assign")
          @action = {:name => 'default_assignee',:action => :index, :partial => 'default_assignee_setup/index', :label => :lable_default_assignee}
          Rails.logger.info "old_tabs: #{@tabs}"
          Rails.logger.info "action: #{@action}"
          @tabs << @action

          end
          @tabs
        end
      end
 end
  end



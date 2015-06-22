module ProjectsControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:

      def modules
        @project.enabled_module_names = params[:enabled_module_names]
        if !@project.enabled_modules.map(&:name).include?('redmine_issue_sla')
          p 'okay am delete ================='
          @project.issue_slas.destroy_all if @project.issue_slas.present?
          @project.issue_sla_statuses.destroy_all if @project.issue_sla_statuses.present?
          @project.response_sla.destroy if @project.response_sla.present?
          @project.sla_working_day.destroy if @project.sla_working_day.present?
        end
        flash[:notice] = l(:notice_successful_update)
        redirect_to settings_project_path(@project, :tab => 'modules')
      end
    end
  end
end

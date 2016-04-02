module ProjectsInfoControllerPatch
  def self.included(base)
    base.class_eval do
      # Insert overrides here, for example:
      # helper :employee_info
      def update
        @project.safe_attributes = params[:project]
        @project.location_id=params[:project][:location_id]
        @project.region_id=params[:project][:region_id]
        if validate_parent_id && @project.save
          @project.set_allowed_parent!(params[:project]['parent_id']) if params[:project].has_key?('parent_id')
          respond_to do |format|
            format.html {
              flash[:notice] = l(:notice_successful_update)
              redirect_to settings_project_path(@project)
            }
            format.api  { render_api_ok }
          end
        else
          respond_to do |format|
            format.html {
              settings
              render :action => 'settings'
            }
            format.api  { render_validation_errors(@project) }
          end
        end
      end


  end
  end
end
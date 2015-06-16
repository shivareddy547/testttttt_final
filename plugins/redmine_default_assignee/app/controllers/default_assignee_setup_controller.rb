class DefaultAssigneeSetupController < ApplicationController
  unloadable


  before_filter :find_project

  def index

    @trackers  = @project.trackers
    @members  = @project.users
    @messages = []
    destory_trackers_and_members(@trackers,@members)
  end

  def result
  @default_assignee = DefaultAssigneeSetup.find_or_initialize_by_project_id_and_tracker_id(:project_id=> params[:project_id],:tracker_id=>params[:tracker_id])
  @default_assignee.default_assignee_to = params[:assigneed_to_id]

  if @default_assignee.save
     flash[:notice] = l(:notice_successful_update)
     # redirect_to default_assignee_setup_index_path({:project_id=>@project.id})
     redirect_to settings_project_path(@project, :tab => 'default_assignee',:tracker_id=>params[:tracker_id])
  else

    @trackers  = @project.trackers
    @members  = @project.users
    render :index
   @messages = []
  end
  end


  private

  def find_project

    #params[:project_id] = 1
    @project = Project.find(params[:project_id])
  end

end

class ProjectLocationSetupController < ApplicationController
  unloadable


  def locations_list

   @locations = ProjectLocation.all

  end

  def new

   @location =  ProjectLocation.new
   @regions= ProjectRegion.all

  end

  def edit

    @location =  ProjectLocation.find(params[:id])
    @regions= ProjectRegion.all

  end

  def create
  @location = ProjectLocation.new
  @location.name=params[:location][:name]
  @location.region_id=params[:location][:region]
  @regions= ProjectRegion.all
  if @location.save
    redirect_to projects_location_list_path
  else
    render "new"

  end

  end

  def update
  @location = ProjectLocation.find(params[:id])
  @location.name=params[:location][:name]
  @location.region_id = params[:location][:region]
  if @location.save
    redirect_to projects_location_list_path
  else
    render "edit"
  end

  end

  def destroy
    @location = ProjectLocation.find(params[:id])
    if @location.delete
      redirect_to projects_location_list_path
    else

    end

  end

  def get_project_locations

    @region=ProjectRegion.find(params[:id])
    @locations = @region.project_locations
    respond_to do |format|
      # render :json => { :attachmentPartial => render_to_string('adsprints/sprint_render', :layout => false, :locals => { :message => "@message" }) }
      format.js {
        render :json => { :locations => @locations }
      }
    end

  end



end

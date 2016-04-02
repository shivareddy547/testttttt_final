class ProjectRegionSetupController < ApplicationController
  unloadable


  def regions_list

    @regions = ProjectRegion.all

  end

  def new

    @region =  ProjectRegion.new

  end

  def edit

    @region =  ProjectRegion.find(params[:id])

  end

  def create
    @new_region = ProjectRegion.new
    @new_region.name=params[:region][:name]

    if @new_region.save
      redirect_to projects_region_list_path
    else
      render "new"
    end

  end

  def update
    @region = ProjectRegion.find(params[:id])
    @region.name=params[:region][:name]

    if @region.save
      redirect_to projects_region_list_path
    else
      render "edit"
    end

  end

  def destroy
    @region = ProjectRegion.find(params[:id])
    if @region.delete
      redirect_to projects_region_list_path
    else

    end

  end



end

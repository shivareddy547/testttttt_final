class ProjectLocation < ActiveRecord::Base
  unloadable

  belongs_to :project_region,:class_name => 'ProjectRegion', :foreign_key => 'region_id'
  validates_presence_of :name, :region_id

end

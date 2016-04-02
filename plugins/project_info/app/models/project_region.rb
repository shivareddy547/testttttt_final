class ProjectRegion < ActiveRecord::Base
  unloadable
  has_many :project_locations,:class_name => 'ProjectLocation', :foreign_key => 'region_id'
  validates_presence_of :name

end

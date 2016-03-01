class ProjectLocation < ActiveRecord::Base
  unloadable

  belongs_to :project_region,:class_name => 'ProjectRegion', :foreign_key => 'region_id'
  validates_presence_of :name, :region_id

  # before_destroy :validate_location

  def validate_location

    @projects= Project.where(:location_id=> self.id )

    errors.add(:location, " can not be delete, it's associated with projects.") if @projects.present?
  end

end

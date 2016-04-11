class OverdueUnmanageTasksSetting < ActiveRecord::Base
  # unloadable
  belongs_to :project_user_preference
  attr_protected :trackers, :statuses,:project_user_preference_id
  serialize :trackers,Array
  serialize :statuses,Array
  serialize :save_text_editor,Array

  def self.project_user_preference_settings(user_id,project_id,block,trackers,statuses)
    project_user_preference = ProjectUserPreference.where(:project_id=>project_id,:user_id=>user_id).last
    project_preference = OverdueUnmanageTasksSetting.find_or_initialize_by_name_and_project_user_preference_id(:name=>block,:project_user_preference_id=>project_user_preference.id)
    project_preference.project_user_preference_id= project_user_preference.id
    return project_preference
  end
end

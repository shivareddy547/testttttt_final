class UserOfficialInfo < ActiveRecord::Base
  unloadable
  belongs_to :user
  validates :employee_id, :presence => true,length: { maximum: 8 }

end

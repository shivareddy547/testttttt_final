class AccessRestriction < ActiveRecord::Base
	def self.check_access_rights
		info = UserOfficialInfo.find_by_user_id(User.current.id)
		rec = AccessRestriction.find_by_employee_id(info.employee_id)
		rec.present? && rec.time_entry_process
	end
end
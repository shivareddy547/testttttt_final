class NcHistory < ActiveRecord::Base
  attr_accessible :date, :employee_id, :employee_name, :nc_master_id, :project_id, :project_l1, :project_l2, :project_l3,:nc_created_for

end

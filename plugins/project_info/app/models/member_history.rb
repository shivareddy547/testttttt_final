class MemberHistory < ActiveRecord::Base
  unloadable



#   def self.get_department_list
#     hrms_sync_details={"adapter"=>ActiveRecord::Base.configurations['hrms_user_sync']['adapter_sync'], "database"=>ActiveRecord::Base.configurations['hrms_user_sync']['database_sync'], "host"=>ActiveRecord::Base.configurations['hrms_user_sync']['host_sync'], "port"=>ActiveRecord::Base.configurations['hrms_user_sync']['port_sync'], "username"=>ActiveRecord::Base.configurations['hrms_user_sync']['username_sync'], "password"=>ActiveRecord::Base.configurations['hrms_user_sync']['password_sync'], "encoding"=>ActiveRecord::Base.configurations['hrms_user_sync']['encoding_sync']}
#
#     inia_database_details = {"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}
#
#     hrms =  ActiveRecord::Base.establish_connection(hrms_sync_details).connection
#
#     inia =  ActiveRecord::Base.establish_connection(:production).connection
#
#     find_employee_no_list = "SELECT employee_no FROM official_info where employee_id in (select id from employee where department_id =(select id from department where name="Delivery Engineering")
# )  )"
#     find_employee_list_result = hrms.execute(find_employee_list)
#
#
#
#
#
#   end

  def self.update_billable_non_billable_for_two_projects


    Member.find_by_sql("y")

  end



end

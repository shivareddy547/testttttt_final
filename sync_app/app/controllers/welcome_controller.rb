class WelcomeController < ApplicationController

  require 'csv'
  def index


    extra_users =[]
    hrms_sync_details={"adapter"=>ActiveRecord::Base.configurations['hrms_user_sync']['adapter_sync'], "database"=>ActiveRecord::Base.configurations['hrms_user_sync']['database_sync'], "host"=>ActiveRecord::Base.configurations['hrms_user_sync']['host_sync'], "port"=>ActiveRecord::Base.configurations['hrms_user_sync']['port_sync'], "username"=>ActiveRecord::Base.configurations['hrms_user_sync']['username_sync'], "password"=>ActiveRecord::Base.configurations['hrms_user_sync']['password_sync'], "encoding"=>ActiveRecord::Base.configurations['hrms_user_sync']['encoding_sync']}
    inia_database_details = {"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}


    # rec = AppSyncInfo.find_or_initialize_by_name('hrms')


    hrms =  ActiveRecord::Base.establish_connection(hrms_sync_details).connection
    @user_info = hrms.execute("SELECT a.first_name, a.last_name, b.login_id,c.work_email, c.employee_no,b.is_active FROM employee a, user b, official_info c where b.id=a.user_id and a.id=c.employee_id and a.modified_date <= '#{Time.now}'")
    hrms.disconnect!
    inia =  ActiveRecord::Base.establish_connection(:production).connection
    @all_users = inia.execute("select login,firstname,lastname,mail from users")



    @all_users.each(:as => :hash) do |user|


      if user['login'].present?
        hrms =  ActiveRecord::Base.establish_connection(hrms_sync_details).connection
      find_user = "select * from user where login_id='#{user['login']}'"
      find_user_res =  hrms.execute(find_user)
      if find_user_res.count == 0
        extra_users << ["#{user['login']}","#{user['firstname']}","#{user['lastname']}","#{user['mail']}"]

      end

        end

    end

    column_names=["login","firstname","lastname","mail"]

    csv_string = CSV.generate do |csv|
      csv << column_names
      extra_users.each do |product|
        csv << product
      end
    end

    respond_to do |format|
      format.html
      format.csv {

      send_data(csv_string, :type => 'text/csv; charset=utf-8; header=present', :filename => "extra_employees_in_inia.csv")
      }

  end



end

end


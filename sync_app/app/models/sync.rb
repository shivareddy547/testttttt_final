
class Sync < ActiveRecord::Base


  def self.sync_sql

    hrms_sync_details={"adapter"=>ActiveRecord::Base.configurations['hrms_user_sync']['adapter_sync'], "database"=>ActiveRecord::Base.configurations['hrms_user_sync']['database_sync'], "host"=>ActiveRecord::Base.configurations['hrms_user_sync']['host_sync'], "port"=>ActiveRecord::Base.configurations['hrms_user_sync']['port_sync'], "username"=>ActiveRecord::Base.configurations['hrms_user_sync']['username_sync'], "password"=>ActiveRecord::Base.configurations['hrms_user_sync']['password_sync'], "encoding"=>ActiveRecord::Base.configurations['hrms_user_sync']['encoding_sync']}

    inia_database_details = {"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}

# AppSyncInfo.establish_connection(inia_database_details)
    rec = AppSyncInfo.find_or_initialize_by_name('hrms')
    rec.in_progress = true
    if !rec.last_sync.present?
      rec.last_sync=Time.now
      @sync_time = (Time.now - 1.minute)
    else
      @sync_time = (rec.last_sync-1.minute)
    end
    rec.save
# hrms_connection =  ActiveRecord::Base.establish_connection(:hrms_sync_details)
    hrms =  ActiveRecord::Base.establish_connection(hrms_sync_details).connection
    # @user_info = hrms.execute("SELECT a.first_name, a.last_name, b.login_id,c.work_email, c.employee_no FROM hrms.employee a, hrms.user b, hrms.official_info c where b.id=a.user_id and a.id=c.employee_id and a.modified_date >= '#{@sync_time}'")
      @user_info = hrms.execute("SELECT a.first_name, a.last_name, b.login_id,b.is_active,c.work_email, c.employee_no FROM hrms.employee a, hrms.user b, hrms.official_info c where b.id=a.user_id and a.id=c.employee_id and a.modified_date >= '#{@sync_time}'")
    hrms.disconnect!
    inia =  ActiveRecord::Base.establish_connection(:production).connection
    @user_info.each(:as => :hash) do |user|

      find_user_with_employee_id = "select * from user_official_infos where user_official_infos.employee_id='#{user['employee_no']}'"
      find_user_with_employee = inia.execute(find_user_with_employee_id)
      if find_user_with_employee.count == 0
        user_insert_query = "INSERT into users(login,firstname,lastname,mail,auth_source_id,created_on,status,type,updated_on)
      VALUES ('#{user['login_id']}','#{user['first_name']}','#{user['last_name']}','#{user['work_email']}',1, NOW(),'#{user['is_active']>=1 ? user['is_active'] : 3 }','User',NOW())"
        save_user = inia.insert_sql(user_insert_query)
        user_info_query = "INSERT into user_official_infos (user_id, employee_id) values ('#{save_user.to_i}',#{user['employee_no']})"
        save_employee = inia.insert_sql(user_info_query)

      else
        find_user_with_employee.each(:as => :hash) do |row|
          user_update_query = "UPDATE users SET login='#{user['login_id']}',firstname='#{user['first_name']}',lastname='#{user['last_name']}'
          ,mail='#{user['work_email']}',auth_source_id=1,status='#{user['is_active'].present? && user['is_active']>=1 ? user['is_active'] : 3 }',updated_on=NOW() where id='#{row["user_id"]}'"
          update_employee = inia.execute(user_update_query)

          # update_user_official_info = "UPDATE user_official_infos SET employee_id=#{user['employee_no']} where user_id=#{row["id"]}"
        end

      end
      rec.update_attributes(:last_sync=>Time.now)
    end
  end

  def self.sync_exist_users

    hrms_sync_details={"adapter"=>ActiveRecord::Base.configurations['hrms_user_sync']['adapter_sync'], "database"=>ActiveRecord::Base.configurations['hrms_user_sync']['database_sync'], "host"=>ActiveRecord::Base.configurations['hrms_user_sync']['host_sync'], "port"=>ActiveRecord::Base.configurations['hrms_user_sync']['port_sync'], "username"=>ActiveRecord::Base.configurations['hrms_user_sync']['username_sync'], "password"=>ActiveRecord::Base.configurations['hrms_user_sync']['password_sync'], "encoding"=>ActiveRecord::Base.configurations['hrms_user_sync']['encoding_sync']}
    inia_database_details = {"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}
    rec = AppSyncInfo.find_or_initialize_by_name('hrms')
    rec.in_progress = true
    if !rec.last_sync.present?
      rec.last_sync=Time.now
      @sync_time = (Time.now - 1.minute)
    else
      @sync_time = (rec.last_sync-1.minute)
    end
    # rec.save
# hrms_connection =  ActiveRecord::Base.establish_connection(:hrms_sync_details)
    hrms =  ActiveRecord::Base.establish_connection(hrms_sync_details).connection
    @user_info = hrms.execute("SELECT a.first_name, a.last_name, b.login_id,c.work_email, c.employee_no,b.is_active FROM hrms.employee a, hrms.user b, hrms.official_info c where b.id=a.user_id and a.id=c.employee_id and a.modified_date <= '#{Time.now}'")
    hrms.disconnect!
    inia =  ActiveRecord::Base.establish_connection(:production).connection
    @user_info.each(:as => :hash) do |user|

      find_user = "select * from users where users.login='#{user['login_id']}'"
      find_user_res =  inia.execute(find_user)

      if find_user_res.count == 0
        # @employee_ids << user['employee_no']
        # @in_active_users << user['login_id']
        user_insert_query = "INSERT into users(login,firstname,lastname,mail,auth_source_id,created_on,status,type,updated_on)
       VALUES ('#{user['login_id']}','#{user['first_name']}','#{user['last_name']}','#{user['work_email']}',1, NOW(),'#{user['is_active'].present? && user['is_active']>=1 ? user['is_active'] : 3 }','User',NOW())"
        save_user = inia.insert_sql(user_insert_query)

        user_info_query = "INSERT into user_official_infos (user_id, employee_id) values ('#{save_user.to_i}',#{user['employee_no']})"
        save_employee = inia.insert_sql(user_info_query)
      else
        # @employee_ids << user['employee_no']
        user_update_query = "UPDATE users SET login='#{user['login_id']}',firstname='#{user['first_name']}',lastname='#{user['last_name']}'
          ,mail='#{user['work_email']}',auth_source_id=1,status='#{user['is_active'].present? && user['is_active']>=1 ? user['is_active'] : 3 }',updated_on=NOW() where login='#{user['login_id']}'"
        update_user = inia.execute(user_update_query)

        find_user_res.each(:as => :hash) do |row|
          find_user = "select * from user_official_infos where user_official_infos.user_id='#{row['id']}'"
          check_employee = inia.execute(find_user)
          if check_employee.count == 0

            user_info_query = "INSERT into user_official_infos (user_id, employee_id) values ('#{row['id']}',#{user['employee_no']})"
            save_employee = inia.insert_sql(user_info_query)
          else
            update_user_official_info = "UPDATE user_official_infos SET employee_id=#{user['employee_no']} where user_id=#{row["id"]}"
            update_employee = inia.execute(update_user_official_info)

          end

        end
      end
      # rec.update_attributes(:last_sync=>Time.now)

    end

  end



  def self.make_users_inactive

    # hrms_sync_details={"adapter"=>ActiveRecord::Base.configurations['hrms_user_sync']['adapter_sync'], "database"=>ActiveRecord::Base.configurations['hrms_user_sync']['database_sync'], "host"=>ActiveRecord::Base.configurations['hrms_user_sync']['host_sync'], "port"=>ActiveRecord::Base.configurations['hrms_user_sync']['port_sync'], "username"=>ActiveRecord::Base.configurations['hrms_user_sync']['username_sync'], "password"=>ActiveRecord::Base.configurations['hrms_user_sync']['password_sync'], "encoding"=>ActiveRecord::Base.configurations['hrms_user_sync']['encoding_sync']}
    #
    # inia_database_details = {"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}
    inia =  ActiveRecord::Base.establish_connection(:production).connection
    all_users = inia.execute("select * from users Where type='User'")

    all_users.each(:as => :hash) do |user|

      user_update_query = "UPDATE users SET login='#{user['login']}',firstname='#{user['firstname']}',lastname='#{user['lastname']}'
          ,mail='#{user['mail']}',auth_source_id=1,status='3',updated_on=NOW() where login='#{user['login']}'"

      update_user = inia.execute(user_update_query)

    end
  end



end

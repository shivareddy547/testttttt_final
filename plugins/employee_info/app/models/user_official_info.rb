require 'spreadsheet'
class UserOfficialInfo < ActiveRecord::Base
  unloadable
  belongs_to :user,dependent: :destroy
  validates :employee_id, :presence => true,length: { maximum: 8 }

  def self.update_employee_ids
   # Active users employee id updation
    User.active.flatten.each do |user|
      user.custom_field_values.each_with_index do |c,index|
        custom_field =CustomField.where(:id=>c.custom_field_id)
        if custom_field.present? && (custom_field.last.name=="Emp_code") && user.custom_field_values[index].to_s.present?

          #user_emp_code << {:user_id=>user.id,:employee_id=> user.custom_field_values[index].to_s}
           UserOfficialInfo.build(user.id,user.custom_field_values[index].to_s.to_i)
        end
      end
    end

  end

  def self.build(user_id,employee_id)
     user_info = UserOfficialInfo.find_or_create_by_user_id(:user_id=>user_id)
     user_info.employee_id=employee_id
     user_info.save
  end

  def self.sync_exist_users

    # hrms_sync_details={"adapter"=>ActiveRecord::Base.configurations['hrms_user_sync']['adapter_sync'], "database"=>ActiveRecord::Base.configurations['hrms_user_sync']['database_sync'], "host"=>ActiveRecord::Base.configurations['hrms_user_sync']['host_sync'], "port"=>ActiveRecord::Base.configurations['hrms_user_sync']['port_sync'], "username"=>ActiveRecord::Base.configurations['hrms_user_sync']['username_sync'], "password"=>ActiveRecord::Base.configurations['hrms_user_sync']['password_sync'], "encoding"=>ActiveRecord::Base.configurations['hrms_user_sync']['encoding_sync']}
    inia_database_details = {"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}
      
    # rec.save
# hrms_connection =  ActiveRecord::Base.establish_connection(:hrms_sync_details)
    hrms =  ActiveRecord::Base.establish_connection(hrms_sync_details).connection
    @user_info = hrms.execute("SELECT a.first_name, a.last_name, b.login_id,c.work_email, c.employee_no,b.is_active FROM employee a, user b, official_info c where b.id=a.user_id and a.id=c.employee_id and a.modified_date <= '#{Time.now}'")
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




  def self.import_from_csv_ofi


    inia =  ActiveRecord::Base.establish_connection(:production).connection

# book = Spreadsheet.open('/home/dgoadmin/redmine/cluster/Node1/employee_info.xls')
    book = Spreadsheet.open('/home/dgoadmin/redmine/cluster/Node1/hrms_feb_25.xls')
    sheet1 = book.worksheet('Sheet1') # can use an index or worksheet name
    sheet1.each do |row|
      break if row[0].nil? # if first cell empty
      # puts row.join(',') # looks like it calls "to_s" on each cell's Value
      p row[1]
      find_user = "select * from users where users.login='#{row[4]}'"
      find_user_res =  inia.execute(find_user)

      if find_user_res.count == 0
        # @employee_ids << user['employee_no']
        # @in_active_users << user['login_id']
        #    user_insert_query = "INSERT into users(login,firstname,lastname,mail,auth_source_id,created_on,status,type,updated_on)
        # VALUES ('#{user['login_id']}','#{user['first_name']}','#{user['last_name']}','#{user['work_email']}',1, NOW(),'#{user['is_active'].present? && user['is_active']>=1 ? user['is_active'] : 3 }','User',NOW())"
        #    save_user = inia.insert_sql(user_insert_query)
        #
        #    user_info_query = "INSERT into user_official_infos (user_id, employee_id) values ('#{save_user.to_i}',#{user['employee_no']})"
        #    save_employee = inia.insert_sql(user_info_query)
      else
        # @employee_ids << user['employee_no']
        user_update_query = "UPDATE users SET login='#{row[4]}' where login='#{row[4]}'"
        update_user = inia.execute(user_update_query)

        find_user_res.each(:as => :hash) do |each_row|
          find_user = "select * from user_official_infos where user_official_infos.user_id='#{each_row['id']}'"
          check_employee = inia.execute(find_user)
          if check_employee.count == 0

            user_info_query = "INSERT into user_official_infos (user_id, employee_id) values ('#{each_row['id']}',#{row[0].to_i})"
            save_employee = inia.insert_sql(user_info_query)
          else
            update_user_official_info = "UPDATE user_official_infos SET employee_id=#{row[0].to_i} where user_id=#{each_row['id'].to_i}"
            update_employee = inia.execute(update_user_official_info)

          end

        end
      end
      # rec.update_attributes(:last_sync=>Time.now)

    end

  end



  def self.import_from_csv

    # hrms_sync_details={"adapter"=>ActiveRecord::Base.configurations['hrms_user_sync']['adapter_sync'], "database"=>ActiveRecord::Base.configurations['hrms_user_sync']['database_sync'], "host"=>ActiveRecord::Base.configurations['hrms_user_sync']['host_sync'], "port"=>ActiveRecord::Base.configurations['hrms_user_sync']['port_sync'], "username"=>ActiveRecord::Base.configurations['hrms_user_sync']['username_sync'], "password"=>ActiveRecord::Base.configurations['hrms_user_sync']['password_sync'], "encoding"=>ActiveRecord::Base.configurations['hrms_user_sync']['encoding_sync']}
    # inia_database_details = {"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}
    # inia_database_details = {"adapter"=>ActiveRecord::Base.configurations['development']['adapter'], "database"=>ActiveRecord::Base.configurations['development']['database'], "host"=>ActiveRecord::Base.configurations['development']['host'], "port"=>ActiveRecord::Base.configurations['development']['port'], "username"=>ActiveRecord::Base.configurations['development']['username'], "password"=>ActiveRecord::Base.configurations['development']['password'], "encoding"=>ActiveRecord::Base.configurations['development']['encoding']}

    inia =  ActiveRecord::Base.establish_connection(:production).connection


    book = Spreadsheet.open('/home/developer/redmine1/employee_info.xls')
    sheet1 = book.worksheet('Sheet1') # can use an index or worksheet name
    sheet1.each do |row|
      break if row[0].nil? # if first cell empty
      # puts row.join(',') # looks like it calls "to_s" on each cell's Value

        find_user = "select * from users where users.login='#{row[1]}'"
        find_user_res =  inia.execute(find_user)

        if find_user_res.count == 0
          # @employee_ids << user['employee_no']
          # @in_active_users << user['login_id']
       #    user_insert_query = "INSERT into users(login,firstname,lastname,mail,auth_source_id,created_on,status,type,updated_on)
       # VALUES ('#{user['login_id']}','#{user['first_name']}','#{user['last_name']}','#{user['work_email']}',1, NOW(),'#{user['is_active'].present? && user['is_active']>=1 ? user['is_active'] : 3 }','User',NOW())"
       #    save_user = inia.insert_sql(user_insert_query)
       #
       #    user_info_query = "INSERT into user_official_infos (user_id, employee_id) values ('#{save_user.to_i}',#{user['employee_no']})"
       #    save_employee = inia.insert_sql(user_info_query)
        else
          # @employee_ids << user['employee_no']
          user_update_query = "UPDATE users SET login='#{row[1]}' where login='#{row[1]}'"
          update_user = inia.execute(user_update_query)

          find_user_res.each(:as => :hash) do |each_row|
            find_user = "select * from user_official_infos where user_official_infos.user_id='#{each_row['id']}'"
            check_employee = inia.execute(find_user)
            if check_employee.count == 0

              user_info_query = "INSERT into user_official_infos (user_id, employee_id) values ('#{each_row['id']}',#{row[0].to_i})"
              save_employee = inia.insert_sql(user_info_query)
            else
              update_user_official_info = "UPDATE user_official_infos SET employee_id=#{row[0].to_i} where user_id=#{each_row['id'].to_i}"
              update_employee = inia.execute(update_user_official_info)

            end

          end
        end
        # rec.update_attributes(:last_sync=>Time.now)

    end

  end




end

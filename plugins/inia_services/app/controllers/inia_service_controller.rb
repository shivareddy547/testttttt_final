require 'custom_value'
class IniaServiceController < ApplicationController
  unloadable





  respond_to  :json
  skip_before_filter :verify_authenticity_token

  # skip_before_filter :verify_authenticity_token
  before_filter :verify_message_api_key,:only=>[:create_ptos,:update_auto_unapproved_entries]
  before_filter :find_project_user,:only=>[:create_ptos]
  before_filter :find_employee_ids_from_date_to_date,:only=>[:update_auto_unapproved_entries]


  def create_ptos
    errors=[]


    if params[:fromDate].present? && params[:toDate].present? && @find_activity_id.present? && @find_issue_id.present? && (params[:leaveCategory]=="Leave" || params[:leaveCategory]=="OnDuty" )

      (params[:fromDate].to_date..params[:toDate].to_date).each do |each_day|
        if !check_lock_status_for_week(each_day,@author.id).present?
          errors << " Leave can not apply for the #{each_day} , it's locked.!"
        end
        @time_entry = TimeEntry.find_or_initialize_by_project_id_and_user_id_and_activity_id_and_spent_on_and_issue_id(@project.first.id,@author.id,@find_activity_id,each_day,@find_issue_id )
        @time_entry.issue_id=@find_issue_id
        @time_entry.comments=  params[:leaveStatus].present?  && params[:leaveStatus]=="Approved" ? params[:leaveDescription] : ""
        if params[:leaveDuration].present?
          if params[:leaveDuration] == "Full day"
            @time_entry.hours = params[:leaveStatus].present?  && params[:leaveStatus]=="Approved"  ? 8 : check_lock_status_for_week(each_day,@author.id).present? ?  0 : 8

          elsif params[:leaveDuration] == "Half day"
            @time_entry.hours = params[:leaveStatus].present?  && params[:leaveStatus]=="Approved"  ? 4 : check_lock_status_for_week(each_day,@author.id).present? ?  0 : 8
          elsif params[:leaveDuration] == "Hours"
            @time_entry.hours = params[:leaveStatus].present?  && params[:leaveStatus]=="Approved"  ? params[:leaveHours].to_f : check_lock_status_for_week(each_day,@author.id).present? ?  0 : params[:leaveHours].to_f

          end

        end
        if !errors.present? && @time_entry.save
          if params[:leaveCategory] != "OnDuty"
            find_leave_type = Project.find_by_sql("select id from custom_fields where type='TimeEntryCustomField' and name='type'")
            if find_leave_type.present?
              cv = CustomValue.find_or_initialize_by_custom_field_id_and_customized_id_and_customized_type(find_leave_type.first.id,@time_entry.id,"TimeEntry")
              # :custom_field_id=>find_leave_type.first.id,:customized_type=>"TimeEntry",:customized_id=>@time_entry.id,:value=>params[:leaveType])
              cv.value=params[:leaveStatus].present?  && params[:leaveStatus]=="Approved"  ? params[:leaveType] : ""
              cv.save
            end

          end

        end
      end
    else
      errors << " Leave can not create for the category..!"

    end

    if errors.present?
      render_json_errors(errors.join(','))
    else
      render_json_ok(@time_entry)
    end

  end

  def check_lock_status_for_week(startday,id)
    user = User.where(:id=>id).last
    check_status=[]
    end_day = (startday+0)
    (startday..end_day).each do |day|
      status = check_time_log_entry(day,user)
      check_status << status
    end
    if check_status.present? && !check_status.include?(false)
      return true
    end
  end


  def check_time_log_entry(select_time,current_user)
    days = Setting.plugin_redmine_wktime['wktime_nonlog_day'].to_i
    setting_hr= Setting.plugin_redmine_wktime['wktime_nonlog_hr'].to_i
    setting_min = Setting.plugin_redmine_wktime['wktime_nonlog_min'].to_i
    wktime_helper = Object.new.extend(WktimeHelper)
    current_time = wktime_helper.set_time_zone(Time.now)
    expire_time = wktime_helper.return_time_zone.parse("#{current_time.year}-#{current_time.month}-#{current_time.day} #{setting_hr}:#{setting_min}")
    deadline_date = UserUnlockEntry.dead_line_final_method
    if deadline_date.present?
      deadline_date = deadline_date.to_date.strftime('%Y-%m-%d').to_date
    end
    lock_status = UserUnlockEntry.where(:user_id=>current_user.id)
    if lock_status.present?
      lock_status_expire_time = lock_status.last.expire_time
      if lock_status_expire_time.to_date <= expire_time.to_date
        lock_status.delete_all
      end
    end
    entry_status =  TimeEntry.where(:user_id=>current_user.id,:spent_on=>select_time.to_date.strftime('%Y-%m-%d').to_date)
    wiki_status_l1=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l1")
    wiki_status_l2=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l2")
    wiki_status_l3=Wktime.where(:user_id=>current_user.id,:begin_date=>select_time.to_date.strftime('%Y-%m-%d').to_date,:status=>"l3")
    permanent_unlock = PermanentUnlock.where(:user_id=>current_user.id)

    if ((select_time.to_date > deadline_date.to_date || lock_status.present?) )

      return true

    elsif ((select_time.to_date == deadline_date.to_date && expire_time > current_time) || lock_status.present? )
      return true
    else

      return false
    end

  end



  def update_auto_unapproved_entries

    start_date = params[:fromDate]
    end_date = params[:toDate]

    if params[:employeeIds].present?
      errors=[]

# p sql = "select * from users u join user_official_infos uo uo.employee_id in (#{params[:employeeIds]})"
      users = User.find_by_sql("select u.id,u.login,u.firstname,u.lastname from users u
  join user_official_infos uo on u.id=uo.user_id where uo.employee_id in (#{params[:employeeIds]})")


      users.each do |each_user|

        find_l2_entries = Wktime.where(:user_id=>each_user,:begin_date=>start_date..end_date,:status=>'l2')
        if !find_l2_entries.present? || (find_l2_entries.count <= (start_date..end_date).to_a.count)
          find_user_project = Member.find_by_sql("select * from members where user_id=530 order by capacity DESC limit 1")

          # l2_user_id = get_perm_for_project(find_user_project.first.project,'l2')
          # l1_user_id = get_perm_for_project(find_user_project.first.project,'l3')

          find_activity = Enumeration.where(:name=>'PTO')
          if find_activity.present?

            @find_activity_id = find_activity.last.id
          else
            errors << "Unable apply for Leave, PTO Activity Not Found .!"
          end
          find_tracker = Tracker.where(:name=>'support')
          if find_tracker.present?
            @find_tracker_id = find_tracker.first.id
          else
            errors << "Unable apply for Leave, PTO Activity Not Found .!"
          end
          find_issue = Issue.where(:project_id=>find_user_project.first.project_id,:tracker_id=>@find_tracker_id,:subject=>'PTO')
          if find_issue.present?
            @find_issue_id = find_issue.first.id
          else
            find_issue = Issue.new(:subject=>"PTO",:project_id=>find_user_project.first.project_id,:tracker_id=>@find_tracker_id,:author_id=>each_user.id,:assigned_to_id=>each_user.id)
            if find_issue.save
              @find_issue_id = find_issue.id
            end
            # errors << "Unable create the Leave, PTO Issue Not Found for #{@project.first.name}.!"
          end
          (start_date..end_date).to_a.each do |each_date|

            @time_entry =  TimeEntry.find_or_initialize_by_project_id_and_user_id_and_activity_id_and_spent_on_and_issue_id(find_user_project.first.project_id,each_user.id,@find_activity_id,each_date,@find_issue_id)
            if @time_entry.present? && @time_entry.id.blank?
              @time_entry.project_id = find_user_project.first.project_id
              @time_entry.activity_id = @find_activity_id

              @time_entry.issue_id = @find_issue_id
              @time_entry.hours = 0.00
              @time_entry.save
            end
            @wktime = Wktime.find_or_initialize_by_user_id_and_begin_date(each_user.id,each_date)
            @wktime.project_id = find_user_project.first.project_id
            @wktime.status="l2"
            @wktime.pre_status=@wktime.status.present? ? @wktime.status : "n"
            @wktime.hours = @wktime.hours.to_f
            @wktime.statusupdate_on = Date.today

            if @wktime.save

              # @wktime = wktime
              find_time_entry_hours = TimeEntry.find_by_sql("select sum(hours) as hours from time_entries where spent_on in ('#{each_date}') and user_id in (#{each_user.id})")

              url = "https://iservstaging.objectfrontier.com/services/employees/autoleaves?"
              if find_time_entry_hours.present?
                if  find_time_entry_hours.first.hours.to_f < 4
                  # lop_request = RestClient.post 'https://iservstaging.objectfrontier.com/services/employees/autoleaves?',:headers => {'Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'}, :param1 => 'one', :content_type => 'application/json'
                  # lop_request
                  # url = "https://iservstaging.objectfrontier.com/services/employees/autoleaves?"
                  # response = RestClient::Request.new(:method => :post,:url => url, :headers => {'Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},  :content_type => 'application/json').execute

                  # url = "https://iservstaging.objectfrontier.com/services/employees/autoleaves?"

                  # RestClient.post(url, { 'x' => 1 }.to_json, :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},:verify_ssl => false)

                  # RestClient.post(url, { 'x' => 1 }.to_json,:verify_ssl=>false ,:content_type => :json, :accept => :json)

                  response = RestClient::Request.execute(:method => :post,:url => url,  :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},  :verify_ssl => false,:payload => {:employeeId => each_user.employee_id, :fromDate => each_date.to_date,:toDate => each_date.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Full day"}.to_json
                  )


                elsif find_time_entry_hours.first.hours.to_f < 8

                  # response = RestClient::Request.execute(:method => :post,:url => url, :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},  :verify_ssl => false, :payload =>  {:employeeId => each_user.employee_id, :fromDate => each_date.to_date,:toDate =>each_date.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Half Day"}
                  # )

                  response = RestClient::Request.execute(:method => :post,:url => url,  :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},  :verify_ssl => false,:payload => {:employeeId => each_user.employee_id, :fromDate => each_date.to_date,:toDate => each_date.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Half day"}.to_json
                  )

                end

              else

                # response = RestClient::Request.execute(:method => :post,:url => url, :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},  :verify_ssl => false, :payload => {:employeeId => '1144', :fromDate => each_day.to_date,:toDate =>each_day.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Full Day"}
                # )
                response = RestClient::Request.execute(:method => :post,:url => url,  :headers =>{'Accept' => 'application/json','Content-Type' => 'application/json','Auth-Key' => 'MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCFiVDf51RLOjpa8Vdz3MBjV0xvvo-pVb0rh4Rz5TKMO_nIQJ0kMUDgp5GbgKeyy0cQLy3rZX4QTRfHaDzc_YRR4sa1hEEReUNrzkfx3SZRs2hm_S1HO9ozt1Pflygy0DxRj0_DCs7eau3Q7cxx6wKziXUjzwvdRoRE4g2Rmnl2IwIDAQAB'},  :verify_ssl => false,:payload => {:employeeId => each_user.employee_id, :fromDate => each_date.to_date,:toDate => each_date.to_date, :leaveDays => "1",:leaveType=>"",:leaveCategory => "Leave",:leaveDescription=>"System leave",:leaveDuration=>"Full day"}.to_json
                )



              end


            else
              errors << @wktime.errors.messages
            end
          end

        end


      end
      # params[:employeeId].each do |each_emp|
      #
      #
      # end


    end

    p "++++++++++++=@wktime@wktime@wktime+++++++++"
    p @wktime
    p "++++end +_+++++++++++++="
    if errors.present?
      render_json_errors(errors.join(','))
    else
      render_json_ok(@wktime)
    end

  end
  # def auto_l2_approve
  #
  #
  #
  #
  # end



  private

  def verify_message_api_key
    if request.present? && request.headers["key"].present?
      find_valid_key = Redmine::Configuration['nalan_api_key'] || File.join(Rails.root, "files")
      (find_valid_key == request.headers["key"].to_s) ? true : render_json_errors("Key Invalid.")
    else
      render_json_errors("Key not found in Url.")
    end
  end


  def find_employee_ids_from_date_to_date
    errors =[]
    if !params[:employeeIds].present?
      errors << "Employee Ids required..!"
    end
    if params[:employeeIds].present? && params[:employeeIds].split(',').count > 1
      errors << "Multiple Employee Ids not allowed..!"
    end
    if !params[:fromDate].present?
      errors << "fromDate requeired..!"
    end
    if !params[:toDate].present?
      errors << "toDate requeired..!"
    end
    if errors.present?
      render_json_errors(errors.join(','))
    end
  end

  def find_project_user
    errors=[]
    # @project = User.find_by_employee(params[:user_id])
    # @tracker = Tracker.find_by_name("IT Operations")

    if !params[:employeeId].blank?
      author = UserOfficialInfo.find_by_employee_id(params[:employeeId])
      if author.present?
        @author = author.user
        if @author.present?
          @project = Project.find_by_sql("select p.id,p.name from projects p join members m on m.project_id=p.id where m.user_id in ('#{@author.id}') and m.capacity > 0  group by project_id order by max(capacity) limit 1")
        end

      else
        errors << "Employee Id Not found"
      end
    else
      errors << "Employee Id required..!"
    end

    if !params[:fromDate].blank?


    else
      errors << "From date required..!"
    end

    if !params[:toDate].blank?


    else
      errors << "To date required..!"
    end

    if !params[:leaveDescription].blank?


    else
      errors << "Leave Reason required..!"
    end

    if !params[:leaveStatus].blank?


    else
      errors << "leaveStatus required..!"
    end

    if !params[:leaveCategory].blank?

    else
      errors << "Leave Category required..!"
    end

    if params[:leaveCategory] == "Leave" && params[:leaveType].blank?
      errors << "Leave Type required..!"
    else

    end

    if !params[:leaveDuration].blank?

    else
      errors << "Full Day Or Half Day Type required..!"
    end

    if @author.present? && @project.present?

      if params[:fromDate].present? && params[:toDate].present?

        find_activity = Enumeration.where(:name=>'PTO')
        if find_activity.present?

          @find_activity_id = find_activity.last.id
        else
          errors << "Unable apply for Leave, PTO Activity Not Found .!"
        end
        find_tracker = Tracker.where(:name=>'support')
        if find_tracker.present?
          @find_tracker_id = find_tracker.first.id
        else
          errors << "Unable apply for Leave, PTO Activity Not Found .!"
        end

        if params[:leaveDuration].present?

          if params[:leaveCategory] != "OnDuty"

            find_issue = Issue.where(:project_id=>@project.first.id,:tracker_id=>@find_tracker_id,:subject=>'PTO')

            if find_issue.present?

              @find_issue_id = find_issue.first.id
            else


              find_issue = Issue.new(:subject=>"PTO",:project_id=>@project.first.id,:tracker_id=>@find_tracker_id,:author_id=>@author.id,:assigned_to_id=>@author.id)
              if find_issue.save

                @find_issue_id = find_issue.id
              end
              # errors << "Unable create the Leave, PTO Issue Not Found for #{@project.first.name}.!"
            end
          else

            find_issue = Issue.where(:project_id=>@project.first.id,:tracker_id=>@find_tracker_id,:subject=>'OnDuty')
            if find_issue.present?

              @find_issue_id = find_issue.first.id
            else

              find_issue = Issue.new(:subject=>"OnDuty",:project_id=>@project.first.id,:tracker_id=>@find_tracker_id,:author_id=>@author.id,:assigned_to_id=>@author.id)
              if find_issue.save

                @find_issue_id = find_issue.id
              end
              # errors << "Unable create the Leave, PTO Issue Not Found for #{@project.first.name}.!"
            end

          end

        else
          errors << "Leave Duration required..!"
        end
        p "++++++++++++=@find_issue_id@find_issue_id+++++++++++++="
        p @find_issue_id


      end

    else
      errors << "Requested person can not apply for leave,Please contact to respective manager..!"

    end
    if errors.present?
      render_json_errors(errors.join(','))
    end

  end


  def render_json_errors(errors)
    render :text => errors, :status => 500,:errors=>errors, :layout => nil
  end

  # def render_json_errors(errors)
  #   render :json => {
  #       :errors=> errors,:status=>500
  #   }
  #
  # end

  def render_json_ok(issue)
    render_json_head(issue,"ok")
  end


  def render_json_head(issue,status)
    # #head would return a response body with one space
    render :json => {:ticket_id=>issue.id}, :status => 200, :layout => nil
  end



end

require 'custom_value'
class IniaServiceController < ApplicationController
  unloadable





  respond_to  :json
  skip_before_filter :verify_authenticity_token

  # skip_before_filter :verify_authenticity_token
  before_filter :verify_message_api_key,:find_project_user,:only=>[:create_ptos]


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



  private

  def verify_message_api_key
    if request.present? && request.headers["key"].present?
      find_valid_key = Redmine::Configuration['nalan_api_key'] || File.join(Rails.root, "files")
      (find_valid_key == request.headers["key"].to_s) ? true : render_json_errors("Key Invalid.")
    else
      render_json_errors("Key not found in Url.")
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
    if !params[:leaveType].blank?

    else
      errors << "Leave Type required..!"
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

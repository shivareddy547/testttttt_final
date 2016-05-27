class IniaServiceController < ApplicationController
  unloadable





  respond_to  :json
  skip_before_filter :verify_authenticity_token

  # skip_before_filter :verify_authenticity_token
  before_filter :verify_message_api_key,:find_project_user,:only=>[:create_ptos]


  def create_ptos
    errors=[]

    p "+++++++=@find_activity_id++++++++"
    p @find_activity_id
    p "+++++++++++++"
    p @find_issue_id
    p "+++++++=end +++"

    if params[:fromDate].present? && params[:toDate].present? && @find_activity_id.present? && @find_issue_id.present? && params[:leaveCategory]=="Leave"

      (params[:fromDate].to_date..params[:toDate].to_date).each do |each_day|
        @time_entry = TimeEntry.find_or_initialize_by_project_id_and_user_id_and_activity_id_and_spent_on(@project.first.id,@author.id,@find_activity_id,each_day )
        @time_entry.issue_id=@find_issue_id
        if params[:fn_or_an].present?
          if params[:fn_or_an] == "Full day"
            @time_entry.hours = 8
          elsif params[:fn_or_an] == "Half day"
            @time_entry.hours = 4
          end

        end
        if @time_entry.save


        end
      end

    else
      errors << " Leave can not create for the category..!"

    end

    if errors.present?
      render_json_errors(errors)
    else
      render_json_ok("Success")
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
p "+++++++++=@author@author+++++++"
          p @author
          p "+++++++end ++++++"
        end

      else
        errors << "Employee Id Not found"
      end
    else
      errors << "Employee Id required..!"
    end

    if !params[:fromDate].blank?
      # @for_project=IniaProject.find_by_identifier(params[:project])
      # unless @for_project
      #   @for_project=IniaProject.find_by_name(params[:project])
      #   unless @for_project
      #     errors << "Project Not Found..!"
      #   end
      # end

    else
      errors << "From date required..!"
    end

    if !params[:leaveCategory].blank?
      # @category =ProjectCategory.find_by_cat_name(params[:category])
      # if @category.present? && @category.cat_name!="General Issues"
      #   errors << "Category Not Found..!"
      # end
      # unless @category
      #   errors << "Category Not Found..!"
      # end
    else
      errors << "Leave Type required..!"
    end

    if !params[:leaveDuration].blank?
      # @category =ProjectCategory.find_by_cat_name(params[:category])
      # if @category.present? && @category.cat_name!="General Issues"
      #   errors << "Category Not Found..!"
      # end
      # unless @category
      #   errors << "Category Not Found..!"
      # end
    else
      errors << "Full Day Or Half Day Type required..!"
    end

    if @author.present? && @project.present?

      if params[:fromDate].present? && params[:toDate].present?

       find_activity = Enumeration.where(:name=>'PTO')
       if find_activity.present?
         p "+++++++============sdfhsjdfsk=========="
         p @find_activity_id = find_activity.last.id
       else
         errors << "Unable apply for Leave, PTO Activity Not Found .!"


       end



       find_tracker = Tracker.where(:name=>'support')
       if find_tracker.present?
         @find_tracker_id = find_tracker.first.id
       else
         errors << "Unable apply for Leave, PTO Activity Not Found .!"

       end

       p "++++==@find_tracker_id@find_tracker_id+++++++++"
       p @find_tracker_id
       p @project
       p "+++++++++++++==end ++++++++"


       find_issue = Issue.where(:project_id=>@project.first.id,:tracker_id=>@find_tracker_id,:subject=>'PTO')
       p "++++++++==issue +++"
       p find_issue
       if find_issue.present?
         @find_issue_id = find_issue.first.id
       else
         errors << "Unable create the Leave, PTO Issue Not Found for #{@project.first.name}.!"

       end

       # if params[:fromDate].present? && params[:endDate].present? && find_activity_id.present? && find_issue.present?
       #
       #   (params[:fromDate].to_date..params[:endDate].to_date).each do |each_day|
       #    @time_entry = TimeEntry.find_or_initialize_by_project_id_and_activity_id_and_spent_on(@project.id,@author.id,each_day ,find_activity_id )
       #    if params[:fn_or_an].present?
       #      if params[:fn_or_an] == "fullDay"
       #        @time_entry.hours = 8
       #      elsif params[:fn_or_an] == "halfDay"
       #        @time_entry.hours = 4
       #      end
       #
       #    end
       #  if @time_entry.save
       #
       #
       #  end
       #  end
       #
       # end




      end

      # member = IniaMember.find_by_user_id_and_project_id(@author.id,@for_project.id)
      # unless member
      #   @for_project=IniaProject.find_by_name(params[:project])
      #   if @for_project.present?
      #     member = IniaMember.find_by_user_id_and_project_id(@author.id,@for_project.id)
      #     unless member
      #       errors << "Requested person is not a member of project..!"
      #     end
      #   else
      #     errors << "Requested person is not a member of project..!"
      #   end
      #
      # end
    else
      errors << "Requested person can not apply for leave,Please contact to respective manager..!"

    end
    if errors.present?
      render_json_errors(errors)
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

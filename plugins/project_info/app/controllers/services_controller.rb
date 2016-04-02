require 'json'
class ServicesController < ApplicationController
  unloadable
  respond_to  :json
  skip_before_filter :verify_authenticity_token
  before_filter :verify_message_api_key,:validate_params


  def append_members
    @project = Project.find(params[:projectId])
    user_id = nil
    user = UserOfficialInfo.find_by_employee_id(params[:employeeId])

    author = UserOfficialInfo.find_by_employee_id(params[:createdBy])
    if params[:employeeId] && user.present?
      #user.id = UserOfficialInfo.find_by_employee_id(params[:user_id]).user_id
      member = Member.new(:role_ids => [params[:roleId]], :user_id => user.user_id, :project_id => @project.id,:capacity => params[:capacity], :billable => '1')
    end
    if user.present? && member.save
      mem = MemberHistory.find_or_initialize_by_user_id_and_project_id(user.user_id,@project.id)
      mem.capacity = params[:capacity].to_f
      mem.billable = params[:billingType].present? && params[:billingType]=='billable' ? params[:billingType] : 'shadow'
      mem.start_date = params[:fromDate]
      mem.end_date = params[:toDate]
      mem.created_by = author.user_id
      mem.member_id=member.id
      mem.save
      render json: {:member_id=>member.id} , :layout => nil and return true
    else
      errors = user.present? ? member.errors : 'OK'
      render :json => errors, :status => 500, :layout => nil and return true
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


  def validate_params
    errors=[]
    if params[:employeeId].present?
       find_user = UserOfficialInfo.find_by_employee_id(params[:employeeId])
       if find_user.present?
       user_for_member = User.find(find_user.user_id)
        if !user_for_member.present?
          errors << "employeeId not valid..!"
        end
       else
         errors << "employeeId not valid..!"
         end
    else
      errors << "employeeId required..!"
    end
    if params[:createdBy].present?
      find_user = UserOfficialInfo.find_by_employee_id(params[:createdBy])
      user_for_created_by = User.find(find_user.id)
      if !user_for_created_by.present?
        errors << "createdBy not valid..!"
      end
    else
      errors << "createdBy required..!"
    end

    if params[:projectId].present?
    find_project = Project.find(params[:projectId])
    else
      errors << "projectId required..!"
    end


    if params[:capacity].present?
      if params[:capacity].to_f <= 0
        errors << "capacity should be greater than 0..!"
      end

      if params[:capacity].to_f > 1
        errors << "capacity should not be greater than 1..!"
      end
    else
      errors << "capacity required..!"
    end

    if params[:roleId].present?
    find_role = Role.find(params[:roleId])
      if !find_role.present?
        errors << "roleId not valid.!"
      end
    else
      errors << "roleId required..!"
    end

    if !params[:fromDate].present?
      # find_role = Role.find(params[:roleId])
      errors << "fromDate required..!"
    end
    if !params[:toDate].present?
      errors << "toDate required..!"
      # find_role = Role.find(params[:roleId])
    end

    if user_for_member.present? && find_project.present?
     find_member = Member.find_by_user_id_and_project_id(user_for_member.id,find_project.id)
      if find_member.present? && find_member.capacity.to_f > 0  
        errors << "Member already exist..!"
      end
    end



    if errors.present?
      render_json_errors(errors)
    end


  end


  def render_json_errors(errors)
    render :json => errors, :status => 500,:errors=>errors, :layout => nil and return true
  end

  def render_json_ok(issue)
    render_json_head(issue,"ok")
  end


  def render_json_head(issue,status)
    render :json => {:ticket_id=>issue}, :status => 200, :layout => nil
  end


end

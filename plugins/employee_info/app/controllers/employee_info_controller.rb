class EmployeeInfoController < ApplicationController
  unloadable

  include ApplicationHelper


  def get_capacity_details_of_other_project
    @members=[]
     member = Member.find(params[:member_id])
     other_project_members = Member.find_by_sql ["SELECT * FROM members WHERE project_id != ? AND user_id =? AND capacity >?", member.project_id,member.user_id,0]
     if other_project_members.present?
     manager_role_id= Role.find_by_name("Manager")
     project_ids_for_other_project = other_project_members.map(&:project_id) if other_project_members.present?
     other_projects = Project.where(:id=>project_ids_for_other_project)
     @collect_other_project_capacity =[]
     other_projects.each do |each_project|
     collect_member_emails =[]
     members = Member.find_by_sql("select * from members inner join member_roles on members.id = member_roles.member_id where members.project_id in (#{each_project.id}) AND members.user_id NOT in (#{member.user_id}) AND member_roles.role_id IN (#{manager_role_id.id})")
     # concat_user_name_with_mail << {project_id=>}
     members.each do |each_member|
       collect_member_emails << each_member.concat_user_name_with_mail
     end
       used_capacity = Member.where(:project_id=>each_project.id,:user_id=>member.user_id)
       @collect_other_project_capacity << {:project_id=> each_project.id, :manager =>collect_member_emails.join(','),:used_capacity=> used_capacity.last.capacity*100}
       end
     end
     # @members =  Member.find_by_sql ["SELECT * FROM members WHERE user_id = ? AND project_id != ?", member.user_id, member.project_id]
    with_format :html do
      @html_content = render_to_string partial: 'employee_info/get_capacity_of_other_project_popup'
    end

    respond_to do |format|
      # render :json => { :attachmentPartial => render_to_string('adsprints/sprint_render', :layout => false, :locals => { :message => "@message" }) }
      format.js {
        render :json => { :CapacityDetailsPartial => @html_content,:member_id=>params[:member_id]}
      }
    end


  end
end

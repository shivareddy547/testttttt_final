module EmployeeInfoHelper

  def capacity(member)
    total_capacity =   Member.where(:user_id=>member.user_id).map(&:capacity).sum*100
    return total_capacity.round
  end

  def available_capacity(member)
    total_capacity =  Member.where(:user_id=>member.user_id).map(&:capacity).sum
    available_capacity = (1-total_capacity)*100
    return available_capacity.round
  end
  def get_role(project)
    # return "yes"
 #   find_member =  Member.find_by_sql("select m.id from members m
 # join member_roles mr on mr.member_id=m.id
 # join roles r on r.id=mr.role_id
 # where r.name in ('CO','DO','Manager')  and m.user_id=#{User.current.id} and m.project_id=#{project.id} limit 1")
 #     if find_member.present? || User.current.admin?
 #       return "true"
 #     else
 #       return "false"
 #     end
 return "true"
  end

  def get_internal_role()
    # return "yes"
   Role.givable_internal.map(&:id)

  end

  def get_role_with_member(member_id)
return "yes"
#     find_member = Member.find(member_id)
#      project_id=find_member.project_id
#     find_member =  Member.find_by_sql("select m.id from members m
# join member_roles mr on mr.member_id=m.id
# join roles r on r.id=mr.role_id
# where r.name in ('co','do')  and m.user_id=#{User.current.id} and m.project_id=#{project_id} limit 1")
#     if find_member.present? || User.current.admin?
#       return "yes"
#     else
#       return "no"
#     end
  end
end

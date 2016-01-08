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


end

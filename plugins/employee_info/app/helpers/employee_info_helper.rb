module EmployeeInfoHelper

  def capacity(member)
   total_capacity =   Member.where(:user_id=>member.user_id).map(&:capacity).sum
   return total_capacity*100
  end

  def available_capacity(member)
    total_capacity =  Member.where(:user_id=>member.user_id).map(&:capacity).sum
    available_capacity = (1-total_capacity)*100
    return available_capacity
  end


end

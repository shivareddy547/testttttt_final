module EmployeeInfo
  module Patches
    module MemberPatch
      def self.included(base)
        #base.extend(ClassMethods)
        # base.send(:include, InstanceMethods)
        base.class_eval do
          # validate :validate_billable
          # validates :capacity,presence:true, numericality: {less_than: 100,:message=>"Utilization should not be grater than 100"},:if=>:validate_availablity

          # validates :billable,:inclusion => {:in => [true, false],:message => "Choose Billable or Non Billable"},:if=>:validate_billable
          validates_uniqueness_of :billable, :scope => [:user_id], :if => :billable

          validates :capacity,presence:true

          # validates_numericality_of :capacity, less_than: ->(self) { (self.capacity*100+self.other_capacity) < 100  }

          validate :capacity_is_less_than_total
          validate :capacity_is_grater_than_total
          validate :validate_billable

          def capacity_is_less_than_total
            errors.add(:Utilization, "should be less than or equal to #{(100-self.other_capacity).round}") if (self.capacity*100+self.other_capacity) > 100
          end
          def capacity_is_grater_than_total
            errors.add(:Utilization, "should be grater than 0") if (self.capacity <= 0)
          end

          def validate_availablity
            current_capacity =  Member.where(:user_id=>self.user_id,:project_id=>self.project_id).map(&:capacity).sum
            total_capacity =  Member.where(:user_id=>self.user_id).map(&:capacity).sum
            other_capacity = total_capacity.to_f - current_capacity.to_f
            return (other_capacity+self.capacity)*100 < 100

          end
          def validate_billable
            if  !["true","false"].include?(self.billable.to_s)
              errors.add(:Choose, "billable or non billable")
            end
          end
          def validate_with_class?
            self.user.class.name == "User"
          end

          def self.capacity(member)
            total_capacity =   Member.where(:user_id=>member.user_id).map(&:capacity).sum*100
            return total_capacity.round
          end

          def self.user_capacity(id)
            total_capacity =   Member.where(:user_id=>id).map(&:capacity).sum*100
            return total_capacity.round
          end

          def self.available_capacity(member)
            total_capacity =  Member.where(:user_id=>member.user_id).map(&:capacity).sum
            available_capacity = (1-total_capacity)*100
            return available_capacity.round
          end
          def self.current_project_capacity(member)
            total_capacity =  Member.where(:user_id=>member.user_id,:project_id=>member.project_id).map(&:capacity).sum*100
            return total_capacity.round
          end

          def self.other_capacity(member)
            current_capacity =  Member.where(:user_id=>member.user_id,:project_id=>member.project_id).map(&:capacity).sum
            total_capacity =  Member.where(:user_id=>member.user_id).map(&:capacity).sum
            other_capacity = (total_capacity.to_f - current_capacity.to_f)*100
            return other_capacity.round
          end
          def other_capacity
            current_capacity =  Member.where(:user_id=>self.user_id,:project_id=>self.project_id).map(&:capacity).sum
            total_capacity =  Member.where(:user_id=>self.user_id).map(&:capacity).sum
            other_capacity = (total_capacity.to_f - current_capacity.to_f)*100
            return other_capacity.round
          end

          def self.user_available_capacity(id)
            total_capacity =  Member.where(:user_id=>id).map(&:capacity).sum
            available_capacity = (1-total_capacity)*100

            return available_capacity.round
          end

# user
#           def self.available_capacity(id)
#             total_capacity =  Member.where(:user_id=>member.user_id).map(&:capacity).sum
#             available_capacity = (1-total_capacity)*100
#             return available_capacity
#           end
#
#
#           def self.other_capacity(id)
#             current_capacity =  Member.where(:user_id=>member.user_id,:project_id=>member.project_id).map(&:capacity).sum
#             total_capacity =  Member.where(:user_id=>member.user_id).map(&:capacity).sum
#             other_capacity = total_capacity.to_f - current_capacity.to_f
#             return other_capacity*100
#           end


          def concat_user_name_with_mail

            return "#{self.user.firstname rescue ""}#{self.user.lastname rescue ""}<#{self.user.mail rescue ""}>"
          end
          def used_capacity
            return self.capacity*100.round
          end

        end


      end

    end

    module ApplicationHelperPatch
      def self.included(base)
        # base.extend(ClassMethods)
        # base.send(:include, InstanceMethods)
        base.class_eval do
          unloadable

          def principals_check_box_tags(name, principals)
            s = ''
            principals.each do |principal|
              s << "<label>#{ check_box_tag name, principal.id, false, :id => "member_ship_check",:member_available_value=> Member.user_available_capacity(principal),:member_available=> Member.user_available_capacity(principal) > 0 ? true : false } #{h principal} (Available: #{Member.user_available_capacity(principal)}%)</label>\n"
            end
            s.html_safe
          end

          def with_format(format, &block)
            old_formats = formats
            self.formats = [format]
            block.call
            self.formats = old_formats
            nil
          end
        end
      end
    end

  end
end




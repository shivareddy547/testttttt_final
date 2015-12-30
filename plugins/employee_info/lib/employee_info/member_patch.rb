module EmployeeInfo
  module Patches
    module MemberPatch
      def self.included(base)
        #base.extend(ClassMethods)
        # base.send(:include, InstanceMethods)
        base.class_eval do
          # validate :validate_billable
          validates :billable,:inclusion => {:in => [true, false],:message => "Choose Billable or Non Billable"},if: :validate_with_class?
          validates_uniqueness_of :billable, :scope => [:user_id], :if => :billable,if: :validate_with_class?

          validates :capacity,presence:true, numericality: {greater_than: 0},if: :validate_with_class?
          def validate_billable
            if !self.billable.present?
               errors.add(:Billable, "can not be blank for #{self.user.firstname.present? ? self.user.firstname : "" }")
            end
          end
          def validate_with_class?
            !User.current.admin? && self.user.class.name =="User"
          end

          def self.capacity(member)
            total_capacity =   Member.where(:user_id=>member.user_id).map(&:capacity).sum
            return total_capacity*100
          end

          def self.available_capacity(member)
            total_capacity =  Member.where(:user_id=>member.user_id).map(&:capacity).sum
            available_capacity = (1-total_capacity)*100
            return available_capacity
          end
          def self.current_project_capacity(member)
            total_capacity =  Member.where(:user_id=>member.user_id,:project_id=>member.project_id).map(&:capacity).sum
            return total_capacity*100
          end

          def self.other_capacity(member)
            current_capacity =  Member.where(:user_id=>member.user_id,:project_id=>member.project_id).map(&:capacity).sum
            total_capacity =  Member.where(:user_id=>member.user_id).map(&:capacity).sum
            other_capacity = total_capacity.to_f - current_capacity.to_f
            return other_capacity*100
          end

          def self.user_available_capacity(user)
            total_capacity =  Member.where(:user_id=>user.id).map(&:capacity).sum
            available_capacity = (1-total_capacity)*100
            return available_capacity
          end

          def concat_user_name_with_mail
           return "#{self.user.firstname}#{self.user.lastname}<#{self.user.mail}>"
          end
          def used_capacity
            return self.capacity*100
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




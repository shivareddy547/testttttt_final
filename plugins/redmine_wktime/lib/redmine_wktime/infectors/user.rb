module RedmineWktime
  module Infectors
    module User
      module ClassMethods; end
  
      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable

          has_one :permanent_unlock, :class_name => 'PermanentUnlock', :foreign_key => 'user_id'
          has_many :user_unlock_entries, :class_name => 'UserUnlockEntry', :foreign_key => 'user_id'
          has_many :user_unlock_histories, :class_name => 'UserUnlockHistory', :foreign_key => 'user_id'
          has_many :rejections, :class_name => 'Rejection', :foreign_key => 'user_id'

          def employee_id
            self.user_official_info.employee_id rescue ""
          end
          def full_name
            "#{self.firstname} #{self.lastname}" rescue ""
          end


        end
      end
      
    end
  end
end
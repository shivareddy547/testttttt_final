module RedmineWktime
  module Infectors
    module Mailer
      module ClassMethods; end
  
      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          def non_entry_users1(user_entries,user)

            @user_entries=user_entries
            @user = user
            mail :to => user.mail,
                 :subject => "Weekly Time Sheet Status  "

          end
          # has_many :rejections, :class_name => 'Rejection', :foreign_key => 'project_id'
        end
      end
      
    end
  end
end
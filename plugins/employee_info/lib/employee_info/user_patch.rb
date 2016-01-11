module EmployeeInfo
  module Patches
    module UserPatch
      def self.included(base)
        #base.extend(ClassMethods)

        #base.send(:include, InstanceMethods)

        base.class_eval do
        has_one :user_official_info


        def concat_user_name_with_mail
          p "dskkkkkkkkkkkkkkkkkkkkkkkksf"
          p self
          return "#{self.firstname rescue ""} #{self.lastname rescue ""}<#{self.mail rescue ""}>"
        end

        end
      end



    end
  end
end




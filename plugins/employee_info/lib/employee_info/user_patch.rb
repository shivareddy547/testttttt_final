module EmployeeInfo
  module Patches
    module UserPatch
      def self.included(base)
        #base.extend(ClassMethods)

        #base.send(:include, InstanceMethods)

        base.class_eval do
        has_one :user_official_info


        end
      end



    end
  end
end




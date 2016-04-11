module ProjectDashboard
  module Infectors
    module Issue
      module ClassMethods
      end
      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          before_save :update_closed_date
          def update_closed_date
            if self.status.is_closed?
              self.closed_date = Time.now
               # self.update_attributes(:closed_date=>Date.today)
            end

          end
        end
      end

      module InstanceMethods

      end
      
    end
  end
end
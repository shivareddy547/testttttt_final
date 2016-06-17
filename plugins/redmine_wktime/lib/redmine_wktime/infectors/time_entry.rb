module RedmineWktime
  module Infectors
    module TimeEntry
      module ClassMethods; end

      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          safe_attributes 'hours', 'comments', 'project_id', 'issue_id', 'activity_id', 'spent_on', 'custom_field_values', 'custom_fields', 'work_location', 'flexioff_reason'

          validates :flexioff_reason, :presence => true, :if => :condition_testing?
          before_save :check_flexioff

          def condition_testing?
            activity.name == 'Flexi OFF' if activity.present?

          end
          def check_flexioff
            self.flexioff_reason= nil if self.flexioff_reason==''
          end

        end
      end

    end
  end
end
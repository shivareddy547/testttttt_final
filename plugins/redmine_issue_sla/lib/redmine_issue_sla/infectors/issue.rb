module RedmineIssueSla
  module Infectors
    module Issue
      module ClassMethods; end
  
      module InstanceMethods
        attr_accessor :attributes_before_change

        def priority_issue_sla
           tracker.issue_slas.where(:project_id => project_id).first
        end

      end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          has_many :sla_times, :class_name => 'SlaTime', :foreign_key => 'issue_id'
          has_one :response_time, :class_name => 'ResponseTime', :foreign_key => 'issue_id'

          after_create :updated_estimated_hours 

          def updated_estimated_hours
            if self.project.enabled_modules.map(&:name).include?('redmine_issue_sla')
              hours = self.project.issue_slas.where(:tracker_id =>self.tracker.id).where(:priority_id => self.priority.id).last.allowed_delay
              self.update_attributes(:estimated_hours => hours )
            end
          end
        end
      end
    end
  end
end
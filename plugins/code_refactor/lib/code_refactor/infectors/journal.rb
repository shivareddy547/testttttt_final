module RedmineImporter
  module Infectors
    module Journal
      module ClassMethods; end
  
      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          #
          after_create :send_notification
           def send_notification

            if self.issue.bulk_update == false  && self.issue.imported == false && notify? && (Setting.notified_events.include?('issue_updated') ||
                (Setting.notified_events.include?('issue_note_added') && notes.present?) ||
                (Setting.notified_events.include?('issue_status_updated') && new_status.present?) ||
                (Setting.notified_events.include?('issue_assigned_to_updated') && detail_for_attribute('assigned_to_id').present?) ||
                (Setting.notified_events.include?('issue_priority_updated') && new_value_for('priority_id').present?)
            )
             Mailer.deliver_issue_edit(self)
           end
           #  if self.issue.imported == false  && notify? && (Setting.notified_events.include?('issue_updated') ||
           #      (Setting.notified_events.include?('issue_note_added') && notes.present?) ||
           #      (Setting.notified_events.include?('issue_status_updated') && new_status.present?) ||
           #      (Setting.notified_events.include?('issue_assigned_to_updated') && detail_for_attribute('assigned_to_id').present?) ||
           #      (Setting.notified_events.include?('issue_priority_updated') && new_value_for('priority_id').present?)
           #  )
           #    Mailer.deliver_issue_edit(self)
           # end

          end

        
        end
      end

    end
  end
end
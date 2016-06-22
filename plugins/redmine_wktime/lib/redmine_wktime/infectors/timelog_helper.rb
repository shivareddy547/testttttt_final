module RedmineWktime
  module Infectors
    module TimelogHelper
      module ClassMethods; end

      module InstanceMethods
        def activity_collection_for_select_options_with_redmine_wktime(time_entry=nil, project=nil)
          project ||= @project
          if project.nil?
            activities = TimeEntryActivity.shared.active.where("active=true and name NOT IN (?)",['PTO','OnDuty'])
          else
            activities = project.activities.where("active=true and name NOT IN (?)",['PTO','OnDuty'])
          end

          collection = []
          if time_entry && time_entry.activity && !time_entry.activity.active?
            collection << [ "--- #{l(:actionview_instancetag_blank_option)} ---", '' ]
          else
            collection << [ "--- #{l(:actionview_instancetag_blank_option)} ---", '' ] unless activities.detect(&:is_default)
          end
          activities.each { |a| collection << [a.name, a.id] }
          collection
        end
      end

      def self.included(receiver)
        receiver.extend         ClassMethods
        receiver.send :include, InstanceMethods
        receiver.class_eval do
          unloadable
          alias_method_chain :activity_collection_for_select_options, :redmine_wktime

        end
      end
    end
  end
end
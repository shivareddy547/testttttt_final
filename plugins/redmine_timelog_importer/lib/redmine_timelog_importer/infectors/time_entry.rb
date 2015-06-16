module RedmineTimelogImporter
  module Infectors
    module TimeEntry
      module ClassMethods; end
  
      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          #validates_numericality_of :external_id,:presence => true
          validates_presence_of :issue_id
          #validates_length_of :notes, :maximum => 255, :allow_nil => true
          #has_one :permanent_unlock, :class_name => 'PermanentUnlock', :foreign_key => 'user_id'
        end
      end
      
    end
  end
end
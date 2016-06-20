module RedmineWktime
  module Infectors
    module TimeEntryFlexi
      module ClassMethods; end

      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable

          validates :flexioff_reason, :presence => true, :if => :condition_testing?
          before_save :check_flexioff

          def condition_testing?
            activity.name == 'Flexi OFF' if activity.present?

          end
          def check_flexioff
            p '=================== test===='
            p self
            self.flexioff_reason= nil if self.flexioff_reason==''
          end

        end
      end

    end
  end
end
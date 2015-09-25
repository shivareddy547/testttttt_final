module ProjectDashboard
  module Infectors
    module Project
      module ClassMethods
      end
      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          #validates_numericality_of :external_id,:presence => true

          #validates_length_of :notes, :maximum => 255, :allow_nil => true
          has_one :project_preference, :dependent => :destroy, :class_name => 'ProjectUserPreference',:foreign_key => 'project_id'
          has_one :dashboard_filter_query, :dependent => :destroy, :class_name => 'DashboardFilterQuery',:foreign_key => 'project_id'
          has_one :query, :class_name => 'DashboardQuery', :dependent => :destroy,:foreign_key => 'project_id'
          def project_user_pref1
            ProjectUserPreference.new(:project => self)
          end
        end
      end

      module InstanceMethods

      end
      
    end
  end
end
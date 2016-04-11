module ProjectDashboard
  module Infectors
    module User
      module ClassMethods
      end
      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          #validates_numericality_of :external_id,:presence => true

          #validates_length_of :notes, :maximum => 255, :allow_nil => true
          has_many :project_preferences, :dependent => :destroy, :class_name => 'ProjectUserPreference',:foreign_key => 'user_id'
          has_many :dashboard_filter_queries, :dependent => :destroy, :class_name => 'DashboardFilterQuery',:foreign_key => 'user_id'
          has_many :queries, :class_name => 'DashboardQuery', :dependent => :delete_all

          def project_user_pref
            ProjectUserPreference.new(:user => self)
          end
        end
      end

      module InstanceMethods

      end
      
    end
  end
end
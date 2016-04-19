module RedmineWktime
  module Infectors
    module Principal
      module ClassMethods; end
  
      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable

    scope :member_of, lambda {|projects|
        projects = [projects].flatten unless projects.is_a?(Array)
        p 3333333333333333333333333333333333
        p projects
        if (projects.all? &:nil?) || projects.empty? 
          where("1=0")
        else
          ids = projects.map(&:id)
          active.where("users.id IN (SELECT DISTINCT user_id FROM members WHERE project_id IN (?))", ids)
        end
      }
          # has_many :rejections, :class_name => 'Rejection', :foreign_key => 'project_id'
        end
      end
      
    end
  end
end
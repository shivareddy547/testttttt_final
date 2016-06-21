module RedmineWktime
  module Infectors
    module Enumeration
      module ClassMethods; end
  
      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          # scope :active, lambda { where(:active => true).where("name NOT IN (?)",'PTO') }
          # has_many :rejections, :class_name => 'Rejection', :foreign_key => 'project_id'
        end
      end
      
    end
  end
end
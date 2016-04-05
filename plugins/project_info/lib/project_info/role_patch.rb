module ProjectInfo
  module Patches
    module RolePatch
      def self.included(base)
        #base.extend(ClassMethods)
        # base.send(:include, InstanceMethods)
        base.class_eval do

         #
         scope :givable_internal, lambda { order("#{table_name}.position ASC").where(:builtin => 0).where(:internal=>true) }
          
          # has_one :project_location,
          # belongs_to :project_location,:class_name => 'ProjectLocation', :foreign_key => 'location_id'
          # belongs_to :project_region,:class_name => 'ProjectRegion', :foreign_key => 'region_id'


        end

      end
    end


  end
end




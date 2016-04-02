module ProjectInfo
  module Patches
    module MemberPatchForHistory
      def self.included(base)
        #base.extend(ClassMethods)
        # base.send(:include, InstanceMethods)
        base.class_eval do


          
          # has_one :project_location,
          # belongs_to :project_location,:class_name => 'ProjectLocation', :foreign_key => 'location_id'
          # belongs_to :project_region,:class_name => 'ProjectRegion', :foreign_key => 'region_id'


        end

      end
    end


  end
end




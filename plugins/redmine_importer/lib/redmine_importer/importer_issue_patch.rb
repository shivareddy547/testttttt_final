module RedmineImporter
  module Patches
    module ImporterIssuePatch
      def self.included(base)
        base.extend(ClassMethods)

        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable

            # before_save :update_parent_task


            # def update_parent_task
            #   self.self_parent_update
            # end


        end
      end

      module ClassMethods

      end

      module InstanceMethods
        def self_parent_update
          if self.parent_id.present? && self.parent_id != 0
          parent = Issue.find(self.parent_id)
          if parent.present?
            @descendants = self.descendants
            Issue.where(id: self.id).update_all(:parent_id=>parent.id,:root_id=>parent.id,:lft=>parent.rgt.to_i+0,:rgt=>parent.rgt.to_i+1)
            updated_issue = Issue.find(self.id)
            @descendants = parent.descendants
            Issue.where(id: parent.id).update_all(:root_id=>parent.id,:rgt=>updated_issue.rgt.to_i+1)

            # if @descendants.present?
            #   # issues_of_descendants = self.descendants
            #   @descendants.each do |each_issue|
            #
            #     Issue.where(id: each_issue.id).update_all(:parent_id=>self.id,:root_id=>self.id,:lft=>self.rgt.to_i-2,:rgt=>self.rgt.to_i-1)
            #
            #     if each_issue.descendants.present?
            #              each_issue.descendants.each do |each_sub_child|
            #                    Issue.where(id: each_sub_child.id).update_all(:parent_id=>each_issue.id,:root_id=>each_issue.id,:lft=>each_issue.rgt.to_i-2,:rgt=>each_issue.rgt.to_i-1)
            #
            #       end
            #     end
            #
            #   end
            # end
            # Issue.where(id: parent.id).update_all(:root_id=>parent.id,:rgt=>updated_issue.rgt.to_i+1)
            # if @descendants.present?
            #   # issues_of_descendants = parent.descendants
            #
            #
            #   @descendants.each do |each_issue|
            #
            #     Issue.where(id: each_issue.id).update_all(:parent_id=>parent.id,:root_id=>parent.id,:lft=>parent.rgt.to_i-2,:rgt=>parent.rgt.to_i-1)
            #
            #     if each_issue.descendants.present?
            #
            #       each_issue.descendants.each do |each_sub_child|
            #
            #         Issue.where(id: each_sub_child.id).update_all(:parent_id=>each_issue.id,:root_id=>each_issue.id,:lft=>each_issue.rgt.to_i-2,:rgt=>each_issue.rgt.to_i-1)
            #
            #       end
            #     end
            #
            #   end
            # end


          end
           end

         end
      end
    end
  end
end

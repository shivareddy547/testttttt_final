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

            Issue.where(id: self.id).update_all(:parent_id=>parent.id,:root_id=>parent.id,:lft=>parent.rgt.to_i+0,:rgt=>parent.rgt.to_i+1)
            updated_issue = Issue.find(self.id)
            Issue.where(id: parent.id).update_all(:root_id=>parent.id,:rgt=>updated_issue.rgt.to_i+1)

          end
           end

          p "++++++++uuuuuuuuuuuuuuuu++isssue++++++++++"
          p self
          p "++++++++parent +++++++++++"
          p self.parent

        end
      end
    end
  end
end

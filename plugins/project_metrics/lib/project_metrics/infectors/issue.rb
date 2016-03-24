module ProjectMetric
  module Infectors
    module Issue
      module ClassMethods; end

      module InstanceMethods

      end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          after_save :update_parent_attributes


          def recalculate_attributes_for(issue_id)

            if issue_id && p = self.class.find(issue_id)
              # priority = highest priority of children
              if priority_position = p.children.joins(:priority).maximum("#{IssuePriority.table_name}.position")
                p.priority = IssuePriority.find_by_position(priority_position)
              end
              # start/due dates = lowest/highest dates of children
              p.start_date = p.children.minimum(:start_date)
              p.due_date = p.children.maximum(:due_date)
              if p.start_date && p.due_date && p.due_date < p.start_date
                p.start_date, p.due_date = p.due_date, p.start_date
              end
              # done ratio = weighted average ratio of leaves
              unless self.class.use_status_for_done_ratio? && p.status && p.status.default_done_ratio
                leaves_count = p.leaves.count
                if leaves_count > 0
                  average = p.leaves.where("estimated_hours > 0").average(:estimated_hours).to_f
                  if average == 0
                    average = 1
                  end
                  done = p.leaves.joins(:status).
                      sum("COALESCE(CASE WHEN estimated_hours > 0 THEN estimated_hours ELSE NULL END, #{average}) " +
                              "* (CASE WHEN is_closed = #{connection.quoted_true} THEN 100 ELSE COALESCE(done_ratio, 0) END)").to_f
                  progress = done / (average * leaves_count)
                  p.done_ratio = progress.round
                end
              end
              # estimate = sum of leaves estimates
              # p.estimated_hours = p.leaves.sum(:estimated_hours).to_f
              # p.estimated_hours = nil if p.estimated_hours == 0.0

              # ancestors will be recursively updated
              p.save(:validate => false)
            end
          end
          def update_parent_attributes
            recalculate_attributes_for(parent_id) if parent_id
          end


        end
      end

    end
  end
end

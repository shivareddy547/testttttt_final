module Infectors
    module Issue
      module ClassMethods; end
      module InstanceMethods; end
      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable
          #
          after_save :after_create_from_copy

          def after_create_from_copy
           return unless copy? && !@after_create_from_copy_handled
            if (@copied_from.project_id == project_id || Setting.cross_project_issue_relations?) && @copy_options[:link] != false
              IssueRelation.skip_callback(:create, :after, :create_journal_after_create)
              relation = IssueRelation.new(:issue_from => @copied_from, :issue_to => self, :relation_type => IssueRelation::TYPE_COPIED_TO)
              unless relation.save
                logger.error "Could not create relation while copying ##{@copied_from.id} to ##{id} due to validation errors: #{relation.errors.full_messages.join(', ')}" if logger
              end
              IssueRelation.set_callback(:create, :after, :create_journal_after_create)
            end

            unless @copied_from.leaf? || @copy_options[:subtasks] == false
              copy_options = (@copy_options || {}).merge(:subtasks => false)
              copied_issue_ids = {@copied_from.id => self.id}
              @copied_from.reload.descendants.reorder("#{Issue.table_name}.lft").each do |child|
                # Do not copy self when copying an issue as a descendant of the copied issue
                next if child == self
                # Do not copy subtasks of issues that were not copied
                next unless copied_issue_ids[child.parent_id]
                # Do not copy subtasks that are not visible to avoid potential disclosure of private data
                unless child.visible?
                  logger.error "Subtask ##{child.id} was not copied during ##{@copied_from.id} copy because it is not visible to the current user" if logger
                  next
                end
                Issue.skip_callback(:create, :after, :send_notification)
                copy = Issue.new.copy_from(child, copy_options)
                copy.author = author
                copy.project = project
                copy.parent_issue_id = copied_issue_ids[child.parent_id]
                unless copy.save
                  logger.error "Could not copy subtask ##{child.id} while copying ##{@copied_from.id} to ##{id} due to validation errors: #{copy.errors.full_messages.join(', ')}" if logger
                  next
                end
                copied_issue_ids[child.id] = copy.id
              end
            end
            @after_create_from_copy_handled = true
         end
        end
      end
    end
  end

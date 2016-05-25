class AddResourceAllocationTypeToOverdueUnmanageTasksSettings < ActiveRecord::Migration
  def change
    add_column :overdue_unmanage_tasks_settings, :allocation_type, :string, array: true, default: []
    # add_column :overdue_unmanage_tasks_settings, :custom_query_name, :string, array: true, default: []
  end
end

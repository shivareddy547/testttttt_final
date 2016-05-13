class AddCustomQueryIdToOverDueManageTasks < ActiveRecord::Migration
  def change
    add_column :overdue_unmanage_tasks_settings, :custom_query_id, :string, array: true, default: []
  end
end

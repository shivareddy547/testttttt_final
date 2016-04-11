class CreateOverdueUnmanageTasksSettings < ActiveRecord::Migration
   def self.up
    create_table :overdue_unmanage_tasks_settings do |t|
      t.column "project_user_preference_id", :integer
      t.column "name", :string
      t.column "trackers", :string,array: true, default: '[]'
      t.column "statuses", :string,array: true, default: '[]'
    end
  end

  def self.down
    drop_table :overdue_unmanage_tasks_settings
  end
end

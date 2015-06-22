class CreateIssueSla < ActiveRecord::Migration
  def change
    create_table :issue_slas, :force => true do |t|
      t.integer :project_id, :null => false
      t.integer :priority_id, :null => false
      t.integer :tracker_id, :null => false
      t.float :allowed_delay

    end
    
    add_column :issues, :expiration_date, :datetime
    add_column :issues, :update_by_manager_date, :datetime
  end

end

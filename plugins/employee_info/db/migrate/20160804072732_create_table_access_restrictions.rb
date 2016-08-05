class CreateTableAccessRestrictions < ActiveRecord::Migration
  def change
  	create_table :access_restrictions do |t|
      t.integer :employee_id
      t.boolean :time_entry_process
      t.timestamps
    end
  end
end

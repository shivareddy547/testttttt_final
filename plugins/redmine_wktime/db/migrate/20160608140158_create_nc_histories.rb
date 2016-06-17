class CreateNcHistories < ActiveRecord::Migration
  def change
    create_table :nc_histories do |t|
      t.integer :employee_id
      t.integer :user_id
      t.integer :member_id
      t.string :employee_name
      t.string :reason
      t.integer :project_id
      t.integer :project_l1
      t.integer :project_l2
      t.integer :project_l3
      t.date :date
      t.string :nc_master_id
      t.string :nc_create_for

      t.timestamps
    end
  end
end

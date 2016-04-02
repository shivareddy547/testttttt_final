class CreateMemberHistories < ActiveRecord::Migration
  def change
    create_table :member_histories do |t|
      t.integer  :member_id
      t.integer :user_id
      t.integer :project_id
      t.date :start_date
      t.date :end_date
      t.enum :billable,:limit => [:billable, :shadow, :support]
      t.datetime :last_modified
      t.float :capacity
      t.integer :created_by
      t.timestamps

    end
  end
end

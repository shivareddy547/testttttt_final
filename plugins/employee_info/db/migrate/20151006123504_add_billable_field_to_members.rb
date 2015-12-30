class AddBillableFieldToMembers < ActiveRecord::Migration
  def change
    add_column :members, :billable, :boolean
  end
end

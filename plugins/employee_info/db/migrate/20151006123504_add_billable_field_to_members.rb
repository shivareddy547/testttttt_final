class AddBillableFieldToMembers < ActiveRecord::Migration
  def change
    # add_column :members, :billable, :integer,default: 0
    add_column :members,:billable , :enum, :limit => [:billable, :shadow, :support]
  end
end

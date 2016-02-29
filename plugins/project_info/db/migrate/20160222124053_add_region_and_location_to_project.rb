class AddRegionAndLocationToProject < ActiveRecord::Migration
  def change
    # add_column :members, :billable, :integer,default: 0
    add_column :projects,:location_id , :integer
    add_column :projects,:region_id , :integer
  end
end

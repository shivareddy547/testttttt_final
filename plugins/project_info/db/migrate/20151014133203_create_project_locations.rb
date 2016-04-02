class CreateProjectLocations < ActiveRecord::Migration
  def change
    create_table :project_locations do |t|
      t.string :name
      t.integer :region_id
    end
  end
end

class CreateProjectRegions < ActiveRecord::Migration
  def change
    create_table :project_regions do |t|
      t.string :name

    end
  end
end

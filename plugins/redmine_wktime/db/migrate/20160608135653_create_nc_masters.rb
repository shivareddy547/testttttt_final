class CreateNcMasters < ActiveRecord::Migration
  def change
    create_table :nc_masters do |t|
      t.string :name
      t.string :nc_type
      t.integer :value_of_day
      t.float :time_in_a_day

      t.timestamps
    end
  end
end

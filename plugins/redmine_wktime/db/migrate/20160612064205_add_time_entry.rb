class AddTimeEntry < ActiveRecord::Migration
  def change
    add_column :time_entries, :work_location, :string
    add_column :time_entries, :flexioff_reason, :string
  end
end
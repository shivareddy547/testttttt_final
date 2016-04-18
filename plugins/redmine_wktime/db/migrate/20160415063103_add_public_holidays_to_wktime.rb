class AddPublicHolidaysToWktime < ActiveRecord::Migration
  def change
    add_column :wktimes, :date, :date
    add_column :wktimes, :location, :string
  end
end

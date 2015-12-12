class AddClosedDateToIssues < ActiveRecord::Migration
  def self.up
    add_column :issues, :closed_date, :datetime

  end

  def self.down
    remove_column :issues, :closed_date

  end
end

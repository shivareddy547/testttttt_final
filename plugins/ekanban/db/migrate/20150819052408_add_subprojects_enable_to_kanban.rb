class AddSubprojectsEnableToKanban < ActiveRecord::Migration
  def self.up
    add_column :kanbans, :subproject_enable, :boolean, :default => false
  end

  def self.down
    remove_column :kanbans, :subproject_enable
  end
end

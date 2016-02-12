class AddColorGroupTypeToKanban < ActiveRecord::Migration
  def self.up
    add_column :kanbans, :color_group_type, :string


  end

  def self.down
    remove_column :kanbans, :color_group_type

  end
end

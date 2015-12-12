class AddGoalAndVelocityToSprints < ActiveRecord::Migration
  def self.up
    add_column :versions, :goal, :text
    add_column :versions, :velocity, :integer
  end

  def self.down
    remove_column :versions, :goal
    remove_column :versions, :velocity
  end
end

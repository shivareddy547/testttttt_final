class AddProjectIdToProjectGoals < ActiveRecord::Migration
  def change
    add_column :project_goals, :project_id, :integer
  end
end

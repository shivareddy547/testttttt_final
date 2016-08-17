class CreateProjectGoals < ActiveRecord::Migration
  def change
    create_table :project_goals do |t|
      t.string :name
      t.float :expected_goal
      t.boolean :active
    end
  end
end

class CreateProjectUserPreferences < ActiveRecord::Migration

  def self.up
    create_table :project_user_preferences do |t|
      t.column "user_id", :integer, :default => 0, :null => false
      t.column "project_id", :integer, :default => 0, :null => false
      t.column "others", :text
    end
  end

  def self.down
    drop_table :project_user_preferences
  end
end

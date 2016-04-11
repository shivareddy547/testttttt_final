class AddSaveTextEditorToOverdueUnmanagementTasks < ActiveRecord::Migration
  def self.up
    add_column :project_user_preferences, :save_text_editor, :text
  end

  def self.down
    remove_column :project_user_preferences, :save_text_editor
  end
end

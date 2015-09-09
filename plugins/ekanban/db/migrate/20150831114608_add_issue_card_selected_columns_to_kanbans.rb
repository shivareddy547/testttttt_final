class AddIssueCardSelectedColumnsToKanbans < ActiveRecord::Migration
  def self.up
    add_column :kanbans, :card_selected_display_columns, :text
    add_column :kanbans, :card_selected_tooltip_columns, :text

  end

  def self.down
    remove_column :kanbans, :card_selected_display_columns
    remove_column :kanbans, :card_selected_tooltip_columns
   end
end

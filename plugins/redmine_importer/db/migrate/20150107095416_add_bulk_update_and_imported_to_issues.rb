class AddBulkUpdateAndImportedToIssues < ActiveRecord::Migration
  def change
    add_column :issues, :bulk_update, :boolean
    add_column :issues, :imported, :boolean
  end
end

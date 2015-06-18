class AddImportedAndBulkUpdateToJournals < ActiveRecord::Migration
  def change
    add_column :journals, :bulk_update, :boolean
    add_column :journals, :imported, :boolean
  end
end

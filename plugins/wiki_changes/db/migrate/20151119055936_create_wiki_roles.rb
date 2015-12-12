class CreateWikiRoles < ActiveRecord::Migration
  def change
    create_table :wiki_roles do |t|
      t.integer :role
      t.string :permissions,array: true, default: []
      t.integer :wiki_page_id
    end
  end
end

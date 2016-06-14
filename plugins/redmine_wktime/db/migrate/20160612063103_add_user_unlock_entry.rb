class AddUserUnlockEntry < ActiveRecord::Migration
  def change
    add_column :user_unlock_entries, :unlock_type, :string
  end
end
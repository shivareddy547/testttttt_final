class AddUserUnlockHistory < ActiveRecord::Migration
  def change
    add_column :user_unlock_histories, :unlock_type, :string
  end
end
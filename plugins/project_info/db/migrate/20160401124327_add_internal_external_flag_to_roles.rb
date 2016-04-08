class AddInternalExternalFlagToRoles < ActiveRecord::Migration
  def change
    add_column :roles, :internal, :boolean,:default => true
  end
end

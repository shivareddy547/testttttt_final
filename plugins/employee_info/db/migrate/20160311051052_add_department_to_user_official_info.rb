class AddDepartmentToUserOfficialInfo < ActiveRecord::Migration
  def change
    add_column :user_official_infos,:department , :string
  end
end

class AddEmpLocationRegionTypeToUserOfficialInfo < ActiveRecord::Migration
  def change
    add_column :user_official_infos, :location_name, :string
    add_column :user_official_infos, :location_type, :string
    add_column :user_official_infos, :region_name, :string
  end
end

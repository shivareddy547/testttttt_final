class CreateNcMasters < ActiveRecord::Migration
  def change
    create_table :nc_masters do |t|
      t.string :nc_id
      t.string :process_id
      t.string :nc_type
      t.string :title
      t.text :description
      t.string :severity
      t.string :responsibility
      t.string :accountability
      t.string :ofs_qms
      t.string :qms_version
      t.string :isms_version
      t.string :document_version
      t.string :version
      t.integer :wktime_nonapprove_day
      t.integer :wktime_nonapprove_hr
      t.integer :wktime_nonapprove_min

      t.timestamps
    end
  end
end

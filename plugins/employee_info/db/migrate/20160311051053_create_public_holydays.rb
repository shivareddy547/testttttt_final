class CreatePublicHolydays < ActiveRecord::Migration
  def change
    create_table :public_holydays do |t|
      t.date :date
      t.string :location
    end
  end
end

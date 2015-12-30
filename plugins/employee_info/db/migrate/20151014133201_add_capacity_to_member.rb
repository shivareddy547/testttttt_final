class AddCapacityToMember < ActiveRecord::Migration
  def change
    add_column :members, :capacity, :float,default: 0.0
  end
end

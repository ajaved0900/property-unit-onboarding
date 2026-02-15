class AddUniqueIndexToUnits < ActiveRecord::Migration[7.1]
  def change
    add_index :units, [:property_id, :number], unique: true
  end
end

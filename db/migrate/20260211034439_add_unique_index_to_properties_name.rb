class AddUniqueIndexToPropertiesName < ActiveRecord::Migration[7.1]
  def change
    add_index :properties, :name, unique: true
  end
end

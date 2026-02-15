class CreateImportBatches < ActiveRecord::Migration[7.1]
  def change
    create_table :import_batches do |t|
      t.jsonb :payload

      t.timestamps
    end
  end
end

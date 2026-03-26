class CreateFormMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :form_mappings do |t|
      t.references :destination, null: false, foreign_key: true
      t.string :name, null: false
      t.text :form_names, null: false

      t.timestamps
    end

    add_index :form_mappings, [:destination_id, :name], unique: true
  end
end

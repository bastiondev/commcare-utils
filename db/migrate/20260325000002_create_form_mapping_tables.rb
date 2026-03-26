class CreateFormMappingTables < ActiveRecord::Migration[8.1]
  def change
    create_table :form_mapping_tables do |t|
      t.references :form_mapping, null: false, foreign_key: true
      t.string :table_name, null: false
      t.string :json_path, null: false, default: '.'
      t.text :sensitive_fields

      t.timestamps
    end

    add_index :form_mapping_tables, [:form_mapping_id, :table_name], unique: true
  end
end

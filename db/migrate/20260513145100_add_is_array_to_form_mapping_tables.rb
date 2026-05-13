class AddIsArrayToFormMappingTables < ActiveRecord::Migration[8.1]
  def change
    add_column :form_mapping_tables, :is_array, :boolean, default: false
  end
end

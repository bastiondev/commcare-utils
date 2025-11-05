class AddSensitiveFieldsToDestinationSources < ActiveRecord::Migration[8.1]
  def change
    add_column :destination_sources, :sensitive_fields, :text, default: nil
  end
end

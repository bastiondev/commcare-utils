class AddCaseNameToDestinationSources < ActiveRecord::Migration[8.1]
  def change
    add_column :destination_sources, :case_name, :string
  end
end

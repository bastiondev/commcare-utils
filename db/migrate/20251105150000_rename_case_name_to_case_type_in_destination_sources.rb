class RenameCaseNameToCaseTypeInDestinationSources < ActiveRecord::Migration[8.1]
  def change
    rename_column :destination_sources, :case_name, :case_type
  end
end

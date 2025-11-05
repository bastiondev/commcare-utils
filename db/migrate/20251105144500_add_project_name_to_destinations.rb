class AddProjectNameToDestinations < ActiveRecord::Migration[8.1]
  def change
    add_column :destinations, :project_name, :string
  end
end

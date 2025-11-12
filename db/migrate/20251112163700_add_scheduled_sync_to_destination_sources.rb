class AddScheduledSyncToDestinationSources < ActiveRecord::Migration[8.1]
  def change
    add_column :destination_sources, :scheduled_sync, :boolean, default: false
  end
end

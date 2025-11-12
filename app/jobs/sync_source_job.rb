class SyncSourceJob < ApplicationJob
  queue_as :default

  def perform(destination_source_id)
    destination_source = DestinationSource.find(destination_source_id)
    Rails.logger.info "Syncing source #{destination_source_id} - #{destination_source.name}"
    num_rows = destination_source.sync_source
    Rails.logger.info "Synced #{num_rows} rows from source #{destination_source_id}"
  end
end
  
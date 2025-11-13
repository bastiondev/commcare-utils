class SyncAllSourcesJob < ApplicationJob
  queue_as :default

  def perform
    DestinationSource.where(scheduled_sync: true).each do |destination_source|
      SyncSourceJob.perform_later(destination_source.id)
    end
  end
end
  
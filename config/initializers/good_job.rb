Rails.application.configure do
  config.good_job.cron = {
    sync_all_sources: {
      description: "Sync all sources daily",
      cron: "0 0 * * *", # Every day at midnight
      class: "SyncAllSourcesJob"
    }
  }
end
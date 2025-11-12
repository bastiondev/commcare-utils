class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Retry all jobs with polynomial backoff, up to 30 attempts
  retry_on StandardError, wait: :polynomially_longer, attempts: 30 do |job, error|
    Rails.logger.error "Job #{job.class.name} (#{job.job_id}) failed after #{job.executions} attempts: #{error.class} - #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if error.backtrace
  end
end

# frozen_string_literal: true

class AnalyzeFileWorker
  include Sidekiq::Job
  sidekiq_options retry: 5, queue: :low, lock: :until_executed

  def perform(id)
    return if Rails.env.test?

    ProductFile.find(id).analyze
  rescue Aws::S3::Errors::NotFound => e
    Rails.logger.info("AnalyzeFileWorker failed: Could not analyze ProductFile #{id} (#{e.class}: #{e.message})")
  end
end

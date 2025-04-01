# frozen_string_literal: true

class RemoveDeletedTranscodedVideosFromS3Worker
  include Sidekiq::Job
  sidekiq_options retry: 1, queue: :default

  def perform
    return unless Feature.active?(:remove_deleted_transcoded_videos_from_s3)

    RemoveDeletedObjectsFromS3.new.remove_transcoded_videos
  end
end

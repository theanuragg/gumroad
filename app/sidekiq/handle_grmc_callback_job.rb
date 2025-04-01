# frozen_string_literal: true

class HandleGrmcCallbackJob
  include Sidekiq::Job
  include TranscodeEventHandler
  sidekiq_options retry: 2, queue: :default

  def perform(notification)
    ActiveRecord::Base.connection.stick_to_primary!

    transcoded_video_from_job = TranscodedVideo.processing.find_by(job_id: notification["job_id"])
    return if transcoded_video_from_job.nil?

    TranscodedVideo.processing.where(original_video_key: transcoded_video_from_job.original_video_key).find_each do |transcoded_video|
      if notification["status"] == "success"
        transcoded_video.product_file.update!(is_transcoded_for_hls: true)
        transcoded_video.update!(transcoded_video_key: transcoded_video.transcoded_video_key + "index.m3u8")
        transcoded_video.mark_completed
      else
        transcoded_video.mark_error
        next if transcoded_video.deleted?
        TranscodeVideoForStreamingWorker.perform_async(
          transcoded_video.product_file_id,
          ProductFile.name,
          TranscodeVideoForStreamingWorker::MEDIACONVERT,
          true
        )
      end
    end
  end
end

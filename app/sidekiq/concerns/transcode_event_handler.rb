# frozen_string_literal: true

module TranscodeEventHandler
  private
    def handle_transcoding_job_notification(job_id, state, transcoded_video_key = nil)
      transcoded_video_from_job = TranscodedVideo.find_by(job_id:)
      return if transcoded_video_from_job.nil?

      TranscodedVideo.processing.where(original_video_key: transcoded_video_from_job.original_video_key).find_each do |transcoded_video|
        transcoded_video.update!(transcoded_video_key:) if transcoded_video_key.present?
        transcoded_video.mark(state.downcase)
        product_file = transcoded_video.product_file
        next if product_file.deleted? || transcoded_video.deleted?

        if transcoded_video.error?
          next if TranscodedVideo.where(original_video_key: transcoded_video_from_job.original_video_key, state: ["processing", "completed"]).exists?
          Rails.logger.info("TranscodeEventHandler => video_transcode_failed: #{transcoded_video.attributes}")
          ContactingCreatorMailer.video_transcode_failed(product_file.id).deliver_now
        else
          product_file.update(is_transcoded_for_hls: true) if transcoded_video.completed? && transcoded_video.is_hls
        end
      end
    end
end

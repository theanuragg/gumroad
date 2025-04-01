# frozen_string_literal: true

class RemoveDeletedObjectsFromS3
  def remove_transcoded_videos
    TranscodedVideo
      .alive_in_cdn
      .joins(:product_file)
      .where.not(product_files: { deleted_from_cdn_at: nil })
      .find_each do |transcoded_video|
      next if transcoded_video.skip_delete_from_cdn?

      transcoded_video_key = transcoded_video.transcoded_video_key

      # Check for product_files which are not deleted from CDN with same transcoded video URL
      product_file_ids = TranscodedVideo.where(transcoded_video_key:).select(:product_file_id)
      if ProductFile.where(id: product_file_ids).alive_in_cdn.exists?
        transcoded_video.skip_delete_from_cdn!
        next
      end

      # Make sure to delete files only if the transcoded_video_key has "/hls/" suffix.
      # Otherwise, it would result in the deletion of unintended files if the transcoded_video_key
      # is set to a wrong path.
      unless transcoded_video_key.end_with?("/hls/")
        transcoded_video.skip_delete_from_cdn!
        next
      end

      bucket.objects(prefix: transcoded_video_key).each do |object|
        delete_from_cdn!(object.key)
      end

      transcoded_video.mark_deleted_from_cdn
    end
  end

  private
    def bucket
      @_bucket ||= begin
        credentials = Aws::Credentials.new(GlobalConfig.get("S3_DELETER_ACCESS_KEY_ID"), GlobalConfig.get("S3_DELETER_SECRET_ACCESS_KEY"))
        s3          = Aws::S3::Resource.new(region: AWS_DEFAULT_REGION, credentials:)
        s3.bucket(S3_BUCKET)
      end
    end

    def delete_from_cdn!(s3_key)
      bucket.object(s3_key).delete
    end
end

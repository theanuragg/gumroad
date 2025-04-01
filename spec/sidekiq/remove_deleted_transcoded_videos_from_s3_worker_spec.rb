# frozen_string_literal: true

require "spec_helper"

describe RemoveDeletedTranscodedVideosFromS3Worker do
  before do
    Feature.activate(:remove_deleted_transcoded_videos_from_s3)
  end

  it "calls the `RemoveDeletedObjectsFromS3#remove_transcoded_videos` method" do
    expect_any_instance_of(RemoveDeletedObjectsFromS3).to receive(:remove_transcoded_videos)

    RemoveDeletedTranscodedVideosFromS3Worker.new.perform
  end
end

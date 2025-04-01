# frozen_string_literal: true

require "spec_helper"

describe DropboxFile do
  describe "validations" do
    it "does not allow you to create a dropbox file without a dropbox url" do
      dropbox_file = DropboxFile.new(dropbox_url: nil)
      expect(dropbox_file.valid?).to eq false
    end
  end

  describe "#multipart_transfer_to_s3", :vcr do
    let(:dropbox_file_info) do
      file = HTTParty.post("https://api.dropboxapi.com/2/files/get_temporary_link",
                           headers: {
                             "Authorization" => "Bearer #{GlobalConfig.get("DROPBOX_API_KEY")}",
                             "Content-Type" => "application/json"
                           },
                           body: { path: "/db_upload_testing/Download-Card.pdf" }.to_json)

      { link: file["link"], name: file["metadata"]["name"], size: file["metadata"]["size"], content_type: "application/pdf" }
    end

    it "copies the file from Dropbox to S3" do
      filename = dropbox_file_info[:name]
      dropbox_url = dropbox_file_info[:link]
      content_type = dropbox_file_info[:content_type]
      content_length = dropbox_file_info[:size]

      allow_any_instance_of(DropboxFile).to receive(:fetch_content_type).and_return(content_type)
      s3_guid = "db" + (SecureRandom.uuid.split("")[1..-1] - ["-"]).join
      create(:dropbox_file, dropbox_url:).multipart_transfer_to_s3(filename, s3_guid)

      s3_object = Aws::S3::Resource.new.bucket(S3_BUCKET).object("attachments/#{s3_guid}/original/#{filename}")
      expect(s3_object.content_type).to eq content_type
      expect(s3_object.content_length).to eq content_length
    end
  end

  describe "callbacks" do
    describe "#schedule_dropbox_file_analyze" do
      it "enqueues the job to transfer the file to S3" do
        create(:dropbox_file)

        expect(TransferDropboxFileToS3Worker).to have_enqueued_sidekiq_job(kind_of(Integer))
      end
    end
  end
end

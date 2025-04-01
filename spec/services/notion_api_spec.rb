# frozen_string_literal: true

require "spec_helper"

describe NotionApi, :vcr do
  let(:user) { create(:user, email: "user@example.com") }

  describe "#get_bot_token" do
    before do
      allow(ENV).to receive(:fetch).with("NOTION_OAUTH_CLIENT_ID").and_return("id-1234")
      allow(ENV).to receive(:fetch).with("NOTION_OAUTH_CLIENT_SECRET").and_return("secret-1234")
    end

    it "retrieves Notion access token" do
      result = described_class.new.get_bot_token(code: "03a0066c-f0cf-442c-bcd9-e1949072d4a0", user:)

      expect(result.parsed_response).to include(
        "access_token" => "secret_cKEExFXDe4r0JxyDDwdqhO9rpMKJ3ZzU797CUG3ctbb",
        "bot_id" => "e511ea88-8c43-410d-848f-0e2804aab14d",
        "token_type" => "bearer"
      )
    end
  end
end

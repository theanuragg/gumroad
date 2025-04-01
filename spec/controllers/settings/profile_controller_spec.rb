# frozen_string_literal: true

require "spec_helper"
require "shared_examples/sellers_base_controller_concern"
require "shared_examples/authorize_called"

describe Settings::ProfileController, :vcr do
  let(:seller) { create(:named_seller) }

  include_context "with user signed in as admin for seller"

  it_behaves_like "authorize called for controller", Settings::ProfilePolicy do
    let(:record) { :profile }
  end

  describe "GET show" do
    it "returns http success and assigns correct instance variables" do
      get :show

      expect(response).to be_successful
      expect(assigns[:title]).to eq("Settings")
      profile_presenter = assigns[:profile_presenter]
      expect(profile_presenter.seller).to eq(seller)
      expect(profile_presenter.pundit_user).to eq(controller.pundit_user)

      settings_presenter = assigns[:settings_presenter]
      expect(settings_presenter.pundit_user).to eq(controller.pundit_user)
    end
  end

  describe "PUT update" do
    before do
      sign_in seller
    end

    it "submits the form successfully" do
      put :update, xhr: true, params: { user: { name: "New name", username: "gum" } }
      expect(response.parsed_body["success"]).to be(true)
      expect(seller.reload.name).to eq("New name")
      expect(seller.username).to eq("gum")
    end

    it "converts a blank username to nil" do
      seller.username = "oldusername"
      seller.save

      expect { put :update, xhr: true, params: { user: { username: "" } } }.to change {
        seller.reload.read_attribute(:username)
      }.from("oldusername").to(nil)
    end

    it "performs model validations" do
      put :update, xhr: true, params: { user: { username: "ab" } }
      expect(response).to have_http_status :unprocessable_content
      expect(response.parsed_body["success"]).to be(false)
      expect(response.parsed_body["error_message"]).to eq("Username is too short (minimum is 3 characters)")
    end

    describe "when the user has not confirmed their email address" do
      before do
        seller.update!(confirmed_at: nil)
      end

      it "returns an error" do
        put :update, xhr: true, params: { user: { name: "New name" } }
        expect(response.parsed_body["success"]).to be(false)
        expect(response.parsed_body["error_message"]).to eq("You have to confirm your email address before you can do that.")
      end
    end

    it "saves tabs and cleans up orphan sections" do
      section1 = create(:seller_profile_products_section, seller:)
      section2 = create(:seller_profile_posts_section, seller:)
      create(:seller_profile_posts_section, seller:)
      create(:seller_profile_posts_section, seller:, product: create(:product))
      seller.avatar.attach(file_fixture("test.png"))

      put :update, params: { tabs: [{ name: "Tab 1", sections: [section1.external_id] }, { name: "Tab 2", sections: [section2.external_id] }, { name: "Tab 3", sections: [] }] }
      puts response.parsed_body
      expect(response).to be_successful
      expect(seller.seller_profile_sections.count).to eq 3
      expect(seller.seller_profile_sections.on_profile.count).to eq 2
      expect(seller.reload.seller_profile.json_data["tabs"]).to eq [{ name: "Tab 1", sections: [section1.id] }, { name: "Tab 2", sections: [section2.id] }, { name: "Tab 3", sections: [] }].as_json
      expect(seller.avatar.attached?).to be(true) # Ensure the avatar remains attached
    end

    it "returns an error if the corresponding blob for the provided 'profile_picture_blob_id' is already removed" do
      seller.avatar.attach(file_fixture("test.png"))
      signed_id = seller.avatar.signed_id

      # Purging an ActiveStorage::Blob in test environment returns Aws::S3::Errors::AccessDenied
      allow_any_instance_of(ActiveStorage::Blob).to receive(:purge).and_return(nil)
      allow(ActiveStorage::Blob).to receive(:find_signed).with(signed_id).and_return(nil)

      seller.avatar.purge

      put :update, params: { user: { name: "New name" }, profile_picture_blob_id: signed_id }
      expect(response.parsed_body["success"]).to be(false)
      expect(response.parsed_body["error_message"]).to eq("The logo is already removed. Please refresh the page and try again.")
    end
  end
end

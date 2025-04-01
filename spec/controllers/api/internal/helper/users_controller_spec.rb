# frozen_string_literal: true

require "spec_helper"

describe Api::Internal::Helper::UsersController do
  include HelperAISpecHelper

  let(:user) { create(:user_with_compliance_info) }
  let(:admin_user) { create(:admin_user) }

  before do
    @params = { email: user.email, timestamp: Time.current.to_i }
  end

  it "inherits from Api::Internal::Helper::BaseController" do
    expect(described_class.superclass).to eq(Api::Internal::Helper::BaseController)
  end

  describe "GET user_info" do
    context "when email parameter is missing" do
      it "returns unauthorized error" do
        get :user_info, params: { timestamp: Time.current.to_i }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when user is not found" do
      it "returns empty prompt and metadata" do
        params = @params.merge(email: "inexistent@example.com")
        set_headers(params:)

        get :user_info, params: params

        expect(response).to have_http_status(:success)
        expect(response.body).to eq({ success: true, user_info: { prompt: "", metadata: {} } }.to_json)
      end
    end

    context "when user info is retrieved" do
      it "returns success response with user info" do
        set_headers(params: @params)

        get :user_info, params: @params

        expect(response).to have_http_status(:success)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["success"]).to be true
        expect(parsed_response["user_info"]["prompt"]).to include("User ID: #{user.id}")
        expect(parsed_response["user_info"]["prompt"]).to include("User Name: #{user.name}")
        expect(parsed_response["user_info"]["prompt"]).to include("User Email: #{user.email}")
        expect(parsed_response["user_info"]["prompt"]).to include("Account Status: Active")
        expect(parsed_response["user_info"]["metadata"]).to eq({
                                                                 "name" => user.name,
                                                                 "value" => 0,
                                                                 "links" => {
                                                                   "Impersonate" => "http://app.test.gumroad.com:31337/admin/helper_actions/impersonate/#{user.external_id}",
                                                                 }
                                                               })
      end
    end
  end

  describe "GET user_suspension_info" do
    let(:auth_headers) { { "Authorization" => "Bearer #{GlobalConfig.get("HELPER_TOOLS_TOKEN")}" } }

    before do
      request.headers.merge!(auth_headers)
    end

    context "when email parameter is missing" do
      it "returns a bad request error" do
        get :user_suspension_info

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error"]).to eq("'email' parameter is required")
      end
    end

    context "when user is not found" do
      it "returns an error message" do
        get :user_suspension_info, params: { email: "nonexistent@example.com" }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error_message"]).to eq("An account does not exist with that email.")
      end
    end

    context "when user is found but not suspended" do
      it "returns non-suspended status" do
        successful_response = instance_double(
          HTTParty::Response,
          code: 200,
          success?: true,
          parsed_response: { "data" => [] }
        )
        allow(HTTParty).to receive(:get).and_return(successful_response)

        get :user_suspension_info, params: { email: user.email }

        expect(response).to have_http_status(:success)
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["status"]).to eq("Compliant")
        expect(response.parsed_body["updated_at"]).to be_nil
        expect(response.parsed_body["appeal_url"]).to be_nil
      end
    end

    context "when user is found and is suspended" do
      it "returns suspended status with details" do
        updated_at = Time.current.iso8601
        appeal_url = "https://appeal.example.com/123"

        user_data = {
          "actionStatus" => "Suspended",
          "actionStatusCreatedAt" => updated_at,
          "appealUrl" => appeal_url
        }

        successful_response = instance_double(
          HTTParty::Response,
          code: 200,
          success?: true,
          parsed_response: { "data" => [user_data] }
        )
        allow(HTTParty).to receive(:get).and_return(successful_response)

        get :user_suspension_info, params: { email: user.email }

        expect(response).to have_http_status(:success)
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["status"]).to eq("Suspended")
        expect(response.parsed_body["updated_at"]).to eq(updated_at)
        expect(response.parsed_body["appeal_url"]).to eq(appeal_url)
      end
    end

    context "when api call to iffy fails" do
      it "returns non-suspended status as default" do
        failed_response = instance_double(
          HTTParty::Response,
          code: 400,
          success?: false,
          parsed_response: {}
        )
        allow(HTTParty).to receive(:get).and_return(failed_response)

        get :user_suspension_info, params: { email: user.email }

        expect(response).to have_http_status(:success)
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["status"]).to eq("Compliant")
        expect(response.parsed_body["updated_at"]).to be_nil
        expect(response.parsed_body["appeal_url"]).to be_nil
      end
    end

    context "when api call to iffy raises a network error" do
      it "notifies Bugsnag and returns an error response" do
        network_error = HTTParty::Error.new("Connection failed")
        allow(HTTParty).to receive(:get).and_raise(network_error)
        expect(Bugsnag).to receive(:notify).with(network_error)

        get :user_suspension_info, params: { email: user.email }

        expect(response).to have_http_status(:service_unavailable)
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error_message"]).to eq("Failed to retrieve suspension information")
      end
    end
  end

  describe "POST send_reset_password_instructions" do
    let(:auth_headers) { { "Authorization" => "Bearer #{GlobalConfig.get("HELPER_TOOLS_TOKEN")}" } }

    context "when email is valid and user exists" do
      it "sends reset password instructions and returns success message" do
        request.headers.merge!(auth_headers)
        expect_any_instance_of(User).to receive(:send_reset_password_instructions)

        post :send_reset_password_instructions, params: { email: user.email }

        expect(response).to have_http_status(:success)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["success"]).to be true
        expect(parsed_response["message"]).to eq("Reset password instructions sent")
      end
    end

    context "when email is valid but user does not exist" do
      it "returns an error message" do
        request.headers.merge!(auth_headers)
        post :send_reset_password_instructions, params: { email: "nonexistent@example.com" }

        expect(response).to have_http_status(:unprocessable_entity)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["error_message"]).to eq("An account does not exist with that email.")
      end
    end

    context "when email is invalid" do
      it "returns an error message" do
        request.headers.merge!(auth_headers)
        post :send_reset_password_instructions, params: { email: "invalid_email" }

        expect(response).to have_http_status(:unprocessable_entity)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["error_message"]).to eq("Invalid email")
      end
    end

    context "when email is missing" do
      it "returns an error message" do
        request.headers.merge!(auth_headers)
        post :send_reset_password_instructions, params: {}

        expect(response).to have_http_status(:unprocessable_entity)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response["error_message"]).to eq("Invalid email")
      end
    end
  end

  describe "POST update_email" do
    let(:auth_headers) { { "Authorization" => "Bearer #{GlobalConfig.get("HELPER_TOOLS_TOKEN")}" } }
    let(:new_email) { "new_email@example.com" }

    context "when email is valid and user exists" do
      it "updates user email and returns success message" do
        request.headers.merge!(auth_headers)

        post :update_email, params: { current_email: user.email, new_email: new_email }

        expect(response).to have_http_status(:success)
        expect(response.parsed_body["message"]).to eq("Email updated.")
        expect(user.reload.unconfirmed_email).to eq(new_email)
      end
    end

    context "when current email is invalid" do
      it "returns an error message" do
        request.headers.merge!(auth_headers)

        post :update_email, params: { current_email: "nonexistent@example.com", new_email: new_email }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error_message"]).to eq("An account does not exist with that email.")
      end
    end

    context "when new email is invalid" do
      it "returns an error message" do
        request.headers.merge!(auth_headers)

        post :update_email, params: { current_email: user.email, new_email: "invalid_email" }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error_message"]).to eq("Invalid new email format.")
      end
    end

    context "when new email is already taken" do
      let(:another_user) { create(:user) }

      it "returns an error message" do
        request.headers.merge!(auth_headers)

        post :update_email, params: { current_email: user.email, new_email: another_user.email }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error_message"]).to eq("An account already exists with this email.")
      end
    end

    context "when required parameters are missing" do
      it "returns an error for missing emails" do
        request.headers.merge!(auth_headers)

        post :update_email, params: {}

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["error_message"]).to eq("Both current and new email are required.")
      end
    end
  end

  describe "POST update_two_factor_authentication_enabled" do
    let(:auth_headers) { { "Authorization" => "Bearer #{GlobalConfig.get("HELPER_TOOLS_TOKEN")}" } }

    context "when email is valid and user exists" do
      it "enables two-factor authentication and returns success message" do
        request.headers.merge!(auth_headers)
        user.update!(two_factor_authentication_enabled: false)

        post :update_two_factor_authentication_enabled, params: { email: user.email, enabled: true }

        expect(response).to have_http_status(:success)
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["message"]).to eq("Two-factor authentication enabled.")
        expect(user.reload.two_factor_authentication_enabled?).to be true
      end

      it "disables two-factor authentication and returns success message" do
        request.headers.merge!(auth_headers)
        user.update!(two_factor_authentication_enabled: true)

        post :update_two_factor_authentication_enabled, params: { email: user.email, enabled: false }

        expect(response).to have_http_status(:success)
        expect(response.parsed_body["success"]).to be true
        expect(response.parsed_body["message"]).to eq("Two-factor authentication disabled.")
        expect(user.reload.two_factor_authentication_enabled?).to be false
      end
    end

    context "when email is invalid or user does not exist" do
      it "returns an error message" do
        request.headers.merge!(auth_headers)

        post :update_two_factor_authentication_enabled, params: { email: "nonexistent@example.com", enabled: true }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error_message"]).to eq("An account does not exist with that email.")
      end
    end

    context "when required parameters are missing" do
      it "returns an error for missing email" do
        request.headers.merge!(auth_headers)

        post :update_two_factor_authentication_enabled, params: { enabled: true }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error_message"]).to eq("Email is required.")
      end

      it "returns an error for missing enabled status" do
        request.headers.merge!(auth_headers)

        post :update_two_factor_authentication_enabled, params: { email: user.email }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.parsed_body["success"]).to be false
        expect(response.parsed_body["error_message"]).to eq("Enabled status is required.")
      end
    end
  end
end

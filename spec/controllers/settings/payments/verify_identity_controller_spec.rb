# frozen_string_literal: false

require "spec_helper"
require "shared_examples/sellers_base_controller_concern"
require "shared_examples/authorize_called"

describe Settings::Payments::VerifyIdentityController, :vcr do
  it_behaves_like "inherits from Sellers::BaseController"

  let!(:user) { create(:user) }
  let!(:user_compliance_info) { create(:user_compliance_info_singapore, user:) }
  let!(:sg_bank_account) { create(:singaporean_bank_account, user:) }
  let!(:tos_agreement) { create(:tos_agreement, user:) }
  let!(:enhanced_id_request) { create(:user_compliance_info_request, user:, field_needed: UserComplianceInfoFields::Individual::STRIPE_ENHANCED_IDENTITY_VERIFICATION) }

  before do
    sign_in user
  end

  it_behaves_like "authorize called for action", :post, :create do
    let(:record) { user }
    let(:policy_klass) { Settings::Payments::UserPolicy }
    let(:policy_method) { :verify_identity? }
  end

  describe "POST create" do
    let!(:stripe_connect_account_id) { StripeMerchantAccountManager.create_account(user, passphrase: "1234").charge_processor_merchant_id }

    it "generates and returns a stripe connect onboarding link" do
      expect(Stripe::AccountLink).to receive(:create).with({
                                                             account: stripe_connect_account_id,
                                                             refresh_url: settings_payments_verify_identity_url,
                                                             return_url: settings_payments_verify_identity_url,
                                                             type: "account_onboarding",
                                                           }).and_call_original

      post :create

      expect(response.parsed_body["success"]).to eq(true)
      expect(response.parsed_body["redirect_url"]).to match(Regexp.new("https://connect.stripe.com/setup/c/#{stripe_connect_account_id}/"))
    end

    it "does nothing and returns if there is no pending enhanced verification request" do
      enhanced_id_request.mark_provided!
      expect(Stripe::AccountLink).not_to receive(:create)

      post :create

      expect(response.parsed_body["success"]).to eq(false)
    end
  end

  describe "GET show" do
    it "displays error if the enhanced verification requirement is still due on stripe" do
      allow_any_instance_of(User).to receive(:stripe_account).and_return(create(:merchant_account, charge_processor_merchant_id: "acct_1MqKd0S7Qv3DpQ7L"))
      stripe_account = Stripe::Account.retrieve("acct_1MqKd0S7Qv3DpQ7L")
      expect(stripe_account["requirements"]["eventually_due"].include?("individual.verification.proof_of_liveness")).to be true

      get :show

      expect(flash[:alert]).to eq("We weren't able to complete your identity verification. Please try again.")
    end

    it "displays success notice if the enhanced verification requirement is not due on stripe anymore" do
      allow_any_instance_of(User).to receive(:stripe_account).and_return(create(:merchant_account, charge_processor_merchant_id: "acct_1MqKg42mV2wyGFoI"))
      stripe_account = Stripe::Account.retrieve("acct_1MqKg42mV2wyGFoI")
      expect(stripe_account["requirements"]["eventually_due"].include?("individual.verification.proof_of_liveness")).to be false

      get :show

      expect(flash[:notice]).to eq("Thanks! You're all set.")
    end
  end
end

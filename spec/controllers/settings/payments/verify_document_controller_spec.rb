# frozen_string_literal: false

require "spec_helper"
require "shared_examples/sellers_base_controller_concern"
require "shared_examples/authorize_called"

describe Settings::Payments::VerifyDocumentController, :vcr do
  it_behaves_like "inherits from Sellers::BaseController"

  let(:user) { create(:user) }
  let(:user_compliance_info) { create(:user_compliance_info, user:, birthday: Date.new(1901, 1, 2)) }
  let(:user_compliance_info_company) { create(:user_compliance_info_business, user:, birthday: Date.new(1901, 1, 2)) }
  let(:user_compliance_info_uae_business) { create(:user_compliance_info_uae_business, user:, birthday: Date.new(1901, 1, 2)) }
  let(:bank_account) { create(:ach_account_stripe_succeed, user:) }
  let(:uae_bank_account) { create(:uae_bank_account, user:) }
  let(:tos_agreement) { create(:tos_agreement, user:) }
  let(:photo_id_request) { create(:user_compliance_info_request, user:, field_needed: UserComplianceInfoFields::Individual::STRIPE_IDENTITY_DOCUMENT_ID) }
  let(:company_id_request) { create(:user_compliance_info_request, user:, field_needed: UserComplianceInfoFields::Business::STRIPE_COMPANY_DOCUMENT_ID) }

  before do
    travel_to(Time.zone.local(2015, 4, 1)) do
      tos_agreement
    end

    @file = fixture_file_upload("success.png", "image/png")
    sign_in user
  end

  it_behaves_like "authorize called for action", :post, :create do
    let(:record) { user }
    let(:policy_klass) { Settings::Payments::UserPolicy }
    let(:policy_method) { :verify_document? }
  end

  describe "POST create" do
    it "uploads the photo identity document to stripe and updates the connect account properly" do
      bank_account
      user_compliance_info
      create(:merchant_account_paypal, user:, charge_processor_verified_at: 1.day.ago)
      expect(user.merchant_accounts.paypal.alive.charge_processor_verified.count).to eq(1)
      merchant_account = StripeMerchantAccountManager.create_account(user, passphrase: "1234")
      expect(user.merchant_accounts.alive.count).to eq(2)

      photo_id_request
      expect(user.user_compliance_info_requests.requested.
          where(field_needed: UserComplianceInfoFields::Individual::STRIPE_IDENTITY_DOCUMENT_ID).count).to eq(1)

      post :create, params: { photo_id: @file }

      expect(response.parsed_body).to eq({ "success" => true })

      stripe_person = Stripe::Account.list_persons(merchant_account.charge_processor_merchant_id)["data"].last
      expect(stripe_person.verification.document.front).to match(/^file_/)
      expect(stripe_person.verification.document.back).to be(nil)
      expect(user.user_compliance_info_requests.requested.
          where(field_needed: UserComplianceInfoFields::Individual::STRIPE_IDENTITY_DOCUMENT_ID).count).to eq(0)
      expect(user.alive_user_compliance_info.stripe_identity_document_id).to match(/^file_/)
    end

    it "uploads the company registration document to stripe and updates the connect account properly" do
      bank_account
      user_compliance_info_company
      merchant_account = StripeMerchantAccountManager.create_account(user, passphrase: "1234")
      expect(user.merchant_accounts.alive.count).to eq(1)

      company_id_request
      expect(user.user_compliance_info_requests.requested.
          where(field_needed: UserComplianceInfoFields::Business::STRIPE_COMPANY_DOCUMENT_ID).count).to eq(1)

      post :create, params: { photo_id: @file, is_company_id: true }

      expect(response.parsed_body).to eq({ "success" => true })

      stripe_account = Stripe::Account.retrieve(merchant_account.charge_processor_merchant_id)
      expect(stripe_account.company.verification.document.front).to match(/^file_/)
      expect(stripe_account.company.verification.document.back).to be(nil)
      expect(user.user_compliance_info_requests.requested.
          where(field_needed: UserComplianceInfoFields::Business::STRIPE_COMPANY_DOCUMENT_ID).count).to eq(0)
      expect(user.alive_user_compliance_info.stripe_company_document_id).to match(/^file_/)
    end

    it "uploads the passport document to stripe and updates the connect account properly" do
      uae_bank_account
      user_compliance_info_uae_business
      StripeMerchantAccountManager.create_account(user, passphrase: "1234")
      expect(user.merchant_accounts.alive.count).to eq(1)
      expect(user.merchant_accounts.alive.last.charge_processor_merchant_id).to be_present

      post :create, params: { photo_id: @file, is_passport: true }

      expect(response.parsed_body).to eq({ "success" => true })
    end

    it "uploads the visa document to stripe and updates the connect account properly" do
      uae_bank_account
      user_compliance_info_uae_business
      StripeMerchantAccountManager.create_account(user, passphrase: "1234")
      expect(user.merchant_accounts.alive.count).to eq(1)
      expect(user.merchant_accounts.alive.last.charge_processor_merchant_id).to be_present

      post :create, params: { photo_id: @file, is_visa: true }

      expect(response.parsed_body).to eq({ "success" => true })
    end

    it "uploads the memorandum of association document to stripe and updates the connect account properly" do
      uae_bank_account
      user_compliance_info_uae_business
      StripeMerchantAccountManager.create_account(user, passphrase: "1234")
      expect(user.merchant_accounts.alive.count).to eq(1)
      expect(user.merchant_accounts.alive.last.charge_processor_merchant_id).to be_present

      post :create, params: { photo_id: @file, is_memorandum_of_association: true }

      expect(response.parsed_body).to eq({ "success" => true })
    end

    it "uploads the power of attorney document to stripe and updates the connect account properly" do
      uae_bank_account
      user_compliance_info_uae_business
      StripeMerchantAccountManager.create_account(user, passphrase: "1234")
      expect(user.merchant_accounts.alive.count).to eq(1)
      expect(user.merchant_accounts.alive.last.charge_processor_merchant_id).to be_present

      post :create, params: { photo_id: @file, is_power_of_attorney: true }

      expect(response.parsed_body).to eq({ "success" => true })
    end

    it "uploads the bank statement document to stripe and updates the connect account properly" do
      uae_bank_account
      user_compliance_info_uae_business
      StripeMerchantAccountManager.create_account(user, passphrase: "1234")
      expect(user.merchant_accounts.alive.count).to eq(1)
      expect(user.merchant_accounts.alive.last.charge_processor_merchant_id).to be_present

      post :create, params: { photo_id: @file, is_bank_statement: true }

      expect(response.parsed_body).to eq({ "success" => true })
    end
  end
end

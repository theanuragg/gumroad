# frozen_string_literal: true

require "spec_helper"

describe Api::Internal::Helper::PurchasesController, :vcr do
  include HelperAISpecHelper

  let(:buyer) { create(:user) }
  let(:admin_user) { create(:admin_user) }

  before do
    @purchase = create(:purchase_in_progress, email: buyer.email, purchaser: buyer, chargeable: create(:chargeable))
    @purchase.process!

    create(:purchase, created_at: 10.days.ago)
    @params = { email: @purchase.email }
    request.headers["Authorization"] = "Bearer #{GlobalConfig.get("HELPER_TOOLS_TOKEN")}"
  end

  it "inherits from Api::Internal::Helper::BaseController" do
    expect(described_class.superclass).to eq(Api::Internal::Helper::BaseController)
  end

  describe "POST reassign_purchases" do
    let(:from_email) { "old@example.com" }
    let(:to_email) { "new@example.com" }
    let!(:target_user) { create(:user, email: to_email) }
    let!(:purchase1) { create(:purchase, email: from_email, purchaser: buyer) }
    let!(:purchase2) { create(:purchase, email: from_email, purchaser: buyer) }
    let!(:purchase3) { create(:purchase, email: from_email, purchaser: nil) }

    context "when both emails are provided" do
      it "reassigns purchases and updates purchaser_id when target user exists" do
        subscription = create(:subscription, user: buyer)
        subscription_purchase = create(:purchase, email: from_email, purchaser: buyer, is_original_subscription_purchase: true, subscription: subscription)

        post :reassign_purchases, params: { from: from_email, to: to_email }

        expect(response).to have_http_status(:success)
        expect(response.parsed_body["success"]).to eq(true)
        expect(response.parsed_body["count"]).to eq(4) # Updated count to include subscription_purchase

        purchase1.reload
        expect(purchase1.email).to eq(to_email)
        expect(purchase1.purchaser_id).to eq(target_user.id)

        purchase2.reload
        expect(purchase2.email).to eq(to_email)
        expect(purchase2.purchaser_id).to eq(target_user.id)

        purchase3.reload
        expect(purchase3.email).to eq(to_email)
        expect(purchase3.purchaser_id).to be_nil

        subscription_purchase.reload
        expect(subscription_purchase.email).to eq(to_email)
        expect(subscription_purchase.purchaser_id).to eq(target_user.id)

        subscription.reload
        expect(subscription.user).to eq(target_user)
      end

      it "reassigns purchases and sets purchaser_id to nil when target user doesn't exist" do
        subscription = create(:subscription, user: buyer)
        subscription_purchase = create(:purchase, email: from_email, purchaser: buyer, is_original_subscription_purchase: true, subscription: subscription)

        expect do
          post :reassign_purchases, params: { from: from_email, to: "nonexistent@example.com" }
        end.to change {
          Purchase.where(email: "nonexistent@example.com").count
        }.from(0).to(4) # Updated count to include subscription_purchase

        expect(response).to have_http_status(:success)
        expect(response.parsed_body["success"]).to eq(true)
        expect(response.parsed_body["count"]).to eq(4) # Updated count to include subscription_purchase

        purchase1.reload
        expect(purchase1.email).to eq("nonexistent@example.com")
        expect(purchase1.purchaser_id).to be_nil

        purchase2.reload
        expect(purchase2.email).to eq("nonexistent@example.com")
        expect(purchase2.purchaser_id).to be_nil

        purchase3.reload
        expect(purchase3.email).to eq("nonexistent@example.com")
        expect(purchase3.purchaser_id).to be_nil

        subscription_purchase.reload
        expect(subscription_purchase.email).to eq("nonexistent@example.com")
        expect(subscription_purchase.purchaser_id).to be_nil

        subscription.reload
        expect(subscription.user).to be_nil
      end
    end

    context "when parameters are missing" do
      it "returns an error when 'from' email is missing" do
        post :reassign_purchases, params: { to: to_email }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["success"]).to eq(false)
        expect(response.parsed_body["message"]).to include("Both 'from' and 'to' email addresses are required")
      end

      it "returns an error when 'to' email is missing" do
        post :reassign_purchases, params: { from: from_email }

        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["success"]).to eq(false)
        expect(response.parsed_body["message"]).to include("Both 'from' and 'to' email addresses are required")
      end
    end

    context "when no purchases are found" do
      it "returns a not found error" do
        post :reassign_purchases, params: { from: "no-purchases@example.com", to: to_email }

        expect(response).to have_http_status(:not_found)
        expect(response.parsed_body["success"]).to eq(false)
        expect(response.parsed_body["message"]).to eq("No purchases found for email: no-purchases@example.com")
      end
    end
  end

  describe "POST refund_last_purchase" do
    before do
      stub_const("GUMROAD_ADMIN_ID", admin_user.id)
    end

    context "when the last purchase can be refunded" do
      it "refunds the purchase" do
        expect do
          post :refund_last_purchase, params: @params
        end.to change { @purchase.reload.refunded? }.from(false).to(true)

        expect(response).to have_http_status(:success)
        expect(response.body).to eq({ success: true, message: "Successfully refunded purchase ID #{@purchase.id}" }.to_json)
      end
    end

    context "when the purchase cannot be refunded" do
      before do
        @error_message = "There is a temporary problem. Try to refund later."
        allow_any_instance_of(Purchase).to receive(:refund_purchase!).and_raise(ChargeProcessorUnavailableError, @error_message)
      end

      it "returns error response" do
        post :refund_last_purchase, params: @params

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to eq({ success: false, message: @error_message }.to_json)
      end
    end
  end

  describe "POST resend_last_receipt" do
    it "resends the last purchase's receipt" do
      post :resend_last_receipt, params: @params

      expect(response).to have_http_status(:success)
      expect(response.body).to eq({ success: true, message: "Successfully resent receipt for purchase ID #{@purchase.id}" }.to_json)
      expect(SendPurchaseReceiptJob).to have_enqueued_sidekiq_job(@purchase.id).on("critical")
    end
  end

  describe "POST resend_receipt_by_number" do
    it "resends the receipt when purchase is found" do
      post :resend_receipt_by_number, params: { purchase_number: @purchase.external_id_numeric }

      expect(response).to have_http_status(:success)
      expect(response.body).to eq({ success: true, message: "Successfully resent receipt for purchase ID #{@purchase.id} to #{@purchase.email}" }.to_json)
      expect(SendPurchaseReceiptJob).to have_enqueued_sidekiq_job(@purchase.id).on("critical")
    end

    it "returns 404 when purchase is not found" do
      post :resend_receipt_by_number, params: { purchase_number: "nonexistent" }

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq({ success: false, error: "Not found" }.to_json)
      expect(SendPurchaseReceiptJob.jobs.size).to eq(0)
    end
  end

  describe "POST search" do
    it "returns error if no parameters are provided" do
      post :search, params: {}

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body[:success]).to eq(false)
      expect(response.parsed_body[:message]).to eq("At least one of the parameters is required.")
    end

    it "returns purchase data if found" do
      purchase_json = @purchase.slice(:email, :link_name, :price_cents, :purchase_state, :created_at)
      purchase_json[:id] = @purchase.external_id_numeric
      purchase_json[:receipt_url] = receipt_purchase_url(@purchase.external_id, host: UrlService.domain_with_protocol, email: @purchase.email)

      post :search, params: @params

      expect(response).to have_http_status(:success)
      expect(response.body).to eq({ success: true, message: "Purchase found", purchase: purchase_json }.to_json)
    end

    it "does not return purchase data if no purchase is found" do
      params = @params.merge(email: "user@example.com")
      post :search, params: params

      expect(response).to have_http_status(:not_found)
      expect(response.body).to eq({ success: false, message: "Purchase not found" }.to_json)
    end

    context "when searching by paypal email" do
      it "returns purchase data if found" do
        purchase = create(:purchase, card_type: CardType::PAYPAL, card_visual: "user@example.com")
        purchase_json = purchase.slice(:email, :link_name, :price_cents, :purchase_state, :created_at)
        purchase_json[:id] = purchase.external_id_numeric
        purchase_json[:receipt_url] = receipt_purchase_url(purchase.external_id, host: UrlService.domain_with_protocol, email: purchase.email)
        params = @params.merge(email: "user@example.com")
        post :search, params: params

        expect(response.body).to eq({ success: true, message: "Purchase found", purchase: purchase_json }.to_json)
      end
    end

    context "when searching by card's last 4" do
      it "returns purchase data if found" do
        purchase = create(:purchase, card_visual: "**** **** **** 4242")
        purchase_json = purchase.slice(:email, :link_name, :price_cents, :purchase_state, :created_at)
        purchase_json[:id] = purchase.external_id_numeric
        purchase_json[:receipt_url] = receipt_purchase_url(purchase.external_id, host: UrlService.domain_with_protocol, email: purchase.email)
        params = { card_last4: "4242", timestamp: Time.now.to_i }
        post :search, params: params

        expect(response.body).to eq({ success: true, message: "Purchase found", purchase: purchase_json }.to_json)
      end
    end

    context "when purchase_date is invalid" do
      it "returns error message" do
        params = { purchase_date: "2021-01", card_type: "other", timestamp: Time.now.to_i }
        post :search, params: params
        expect(response).to have_http_status(:bad_request)
        expect(response.body).to eq({ success: false, message: "purchase_date must use YYYY-MM-DD format." }.to_json)
      end
    end

    context "when searching by charge amount" do
      it "returns purchase data if found" do
        purchase = create(:purchase, price_cents: 1000)
        purchase_json = purchase.slice(:email, :link_name, :price_cents, :purchase_state, :created_at)
        purchase_json[:id] = purchase.external_id_numeric
        purchase_json[:receipt_url] = receipt_purchase_url(purchase.external_id, host: UrlService.domain_with_protocol, email: purchase.email)
        params = { charge_amount: "10.00", timestamp: Time.now.to_i }
        post :search, params: params

        expect(response.body).to eq({ success: true, message: "Purchase found", purchase: purchase_json }.to_json)
      end
    end
  end
end

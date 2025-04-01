# frozen_string_literal: true

require "spec_helper"

describe Collaborator::CreateService do
  describe "#process" do
    let(:seller) { create(:user) }
    let(:collaborating_user) { create(:user) }
    let(:products) { create_list(:product, 3, user: seller) }
    let!(:enabled_products) { products.first(2) }
    let(:params) do
      {
        email: collaborating_user.email,
        apply_to_all_products: true,
        percent_commission: 30,
        products: enabled_products.map { { id: _1.external_id } }
      }
    end

    context "with 'apply_to_all_products' enabled" do
      it "creates a collaborator" do
        expect do
          result = described_class.new(seller:, params:).process
          expect(result).to eq({ success: true })
        end.to change { seller.collaborators.count }.from(0).to(1)
           .and change { ProductAffiliate.count }.from(0).to(2)

        collaborator = seller.collaborators.find_by(affiliate_user_id: collaborating_user.id)
        expect(collaborator.apply_to_all_products).to eq true
        expect(collaborator.affiliate_percentage).to eq 30

        enabled_products.each do |product|
          pa = collaborator.product_affiliates.find_by(product:)
          expect(pa).to be_present
          expect(pa.affiliate_percentage).to eq 30
        end
      end
    end

    context "with 'apply_to_all_products' disabled" do
      let(:product1) { enabled_products.first }
      let(:product2) { enabled_products.last }
      let(:params) do
        {
          email: collaborating_user.email,
          apply_to_all_products: false,
          percent_commission: nil,
          products: [
            { id: product1.external_id, percent_commission: 25 },
            { id: product2.external_id, percent_commission: 50 },
          ],
        }
      end

      it "creates a collaborator" do
        expect do
          result = described_class.new(seller:, params:).process
          expect(result).to eq({ success: true })
        end.to change { seller.collaborators.count }.from(0).to(1)
           .and change { ProductAffiliate.count }.from(0).to(2)
           .and have_enqueued_mail(AffiliateMailer, :collaborator_creation).with { Collaborator.last.id }

        collaborator = seller.collaborators.find_by(affiliate_user_id: collaborating_user.id)
        expect(collaborator.apply_to_all_products).to eq false
        expect(collaborator.affiliate_percentage).to be_nil

        pa = collaborator.product_affiliates.find_by(product: product1)
        expect(pa).to be_present
        expect(pa.affiliate_percentage).to eq 25

        pa = collaborator.product_affiliates.find_by(product: product2)
        expect(pa).to be_present
        expect(pa.affiliate_percentage).to eq 50
      end

      it "returns an error when commission is missing" do
        params[:products] = [
          { id: product1.external_id, percent_commission: 50 },
          { id: product2.external_id },
        ]

        expect do
          result = described_class.new(seller:, params:).process
          expect(result).to eq({ success: false, message: "Product affiliates affiliate basis points must be greater than or equal to 100" })
        end.to change { seller.collaborators.count }.by(0)
           .and change { ProductAffiliate.count }.by(0)
      end
    end

    it "creates a collaborator if the user is associated with a deleted collaborator" do
      create(:collaborator, seller:, affiliate_user: collaborating_user, deleted_at: Time.current)
      expect do
        result = described_class.new(seller:, params:).process
        expect(result).to eq({ success: true })
      end.to change { seller.collaborators.count }.from(1).to(2)
         .and change { ProductAffiliate.count }.from(0).to(2)
    end

    it "returns an error if the user cannot be found" do
      params[:email] = "foo@example.com"
      result = described_class.new(seller:, params:).process
      expect(result).to eq({ success: false, message: "The email address isn't associated with a Gumroad account." })
    end

    it "returns an error if the user is already a collaborator" do
      create(:collaborator, seller:, affiliate_user: collaborating_user)
      result = described_class.new(seller:, params:).process
      expect(result).to eq({ success: false, message: "The user is already a collaborator" })
    end

    it "returns an error if product cannot be found" do
      params[:products] = [{ id: "abc123" }]
      result = described_class.new(seller:, params:).process
      expect(result).to eq({ success: false, message: "Product not found" })
    end

    it "returns an error if the user requires approval of any collaborator requests" do
      collaborating_user.update!(require_collab_request_approval: true)
      result = described_class.new(seller:, params:).process
      expect(result).to eq({ success: false, message: "You cannot add this user as a collaborator" })
    end

    it "returns an error if the seller is using a Brazilian Stripe Connect account" do
      brazilian_stripe_account = create(:merchant_account_stripe_connect, user: seller, country: "BR")
      seller.update!(check_merchant_account_is_linked: true)
      expect(seller.merchant_account(StripeChargeProcessor.charge_processor_id)).to eq brazilian_stripe_account

      result = described_class.new(seller:, params:).process
      expect(result).to eq({ success: false, message: "You cannot add a collaborator because you are using a Brazilian Stripe account." })
    end

    it "returns an error if the collaborating user is using a Brazilian Stripe Connect account" do
      brazilian_stripe_account = create(:merchant_account_stripe_connect, user: collaborating_user, country: "BR")
      collaborating_user.update!(check_merchant_account_is_linked: true)
      expect(collaborating_user.merchant_account(StripeChargeProcessor.charge_processor_id)).to eq brazilian_stripe_account

      result = described_class.new(seller:, params:).process
      expect(result).to eq({ success: false, message: "This user cannot be added as a collaborator because they use a Brazilian Stripe account." })
    end
  end
end

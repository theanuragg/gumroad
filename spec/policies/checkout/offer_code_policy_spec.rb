# frozen_string_literal: true

require "spec_helper"

describe Checkout::OfferCodePolicy do
  subject { described_class }

  let(:accountant_for_seller) { create(:user) }
  let(:admin_for_seller) { create(:user) }
  let(:marketing_for_seller) { create(:user) }
  let(:support_for_seller) { create(:user) }
  let(:seller) { create(:named_seller) }

  before do
    create(:team_membership, user: accountant_for_seller, seller:, role: TeamMembership::ROLE_ACCOUNTANT)
    create(:team_membership, user: admin_for_seller, seller:, role: TeamMembership::ROLE_ADMIN)
    create(:team_membership, user: marketing_for_seller, seller:, role: TeamMembership::ROLE_MARKETING)
    create(:team_membership, user: support_for_seller, seller:, role: TeamMembership::ROLE_SUPPORT)
  end

  permissions :index?, :paged? do
    it "grants access to owner" do
      seller_context = SellerContext.new(user: seller, seller:)
      expect(subject).to permit(seller_context, OfferCode)
    end

    it "grants access to accountant" do
      seller_context = SellerContext.new(user: accountant_for_seller, seller:)
      expect(subject).to permit(seller_context, OfferCode)
    end

    it "grants access to admin" do
      seller_context = SellerContext.new(user: admin_for_seller, seller:)
      expect(subject).to permit(seller_context, OfferCode)
    end

    it "grants access to marketing" do
      seller_context = SellerContext.new(user: marketing_for_seller, seller:)
      expect(subject).to permit(seller_context, OfferCode)
    end

    it "grants access to support" do
      seller_context = SellerContext.new(user: support_for_seller, seller:)
      expect(subject).to permit(seller_context, OfferCode)
    end
  end

  permissions :create? do
    it "grants access to owner" do
      seller_context = SellerContext.new(user: seller, seller:)
      expect(subject).to permit(seller_context, OfferCode)
    end

    it "denies access to accountant" do
      seller_context = SellerContext.new(user: accountant_for_seller, seller:)
      expect(subject).to_not permit(seller_context, OfferCode)
    end

    it "grants access to admin" do
      seller_context = SellerContext.new(user: admin_for_seller, seller:)
      expect(subject).to permit(seller_context, OfferCode)
    end

    it "grants access to marketing" do
      seller_context = SellerContext.new(user: marketing_for_seller, seller:)
      expect(subject).to permit(seller_context, OfferCode)
    end

    it "denies access to support" do
      seller_context = SellerContext.new(user: support_for_seller, seller:)
      expect(subject).not_to permit(seller_context, OfferCode)
    end
  end

  permissions :update?, :destroy? do
    context "when the offer code belongs to seller" do
      let(:offer_code) { create(:offer_code, user: seller) }

      it "grants access to owner" do
        seller_context = SellerContext.new(user: seller, seller:)
        expect(subject).to permit(seller_context, offer_code)
      end

      it "denies access to accountant" do
        seller_context = SellerContext.new(user: accountant_for_seller, seller:)
        expect(subject).to_not permit(seller_context, offer_code)
      end

      it "grants access to admin" do
        seller_context = SellerContext.new(user: admin_for_seller, seller:)
        expect(subject).to permit(seller_context, offer_code)
      end

      it "grants access to marketing" do
        seller_context = SellerContext.new(user: marketing_for_seller, seller:)
        expect(subject).to permit(seller_context, offer_code)
      end

      it "denies access to support" do
        seller_context = SellerContext.new(user: support_for_seller, seller:)
        expect(subject).not_to permit(seller_context, offer_code)
      end
    end

    context "when the offer code belongs to other user" do
      let(:offer_code) { create(:offer_code) }

      it "denies access to owner" do
        seller_context = SellerContext.new(user: seller, seller:)
        expect(subject).to_not permit(seller_context, offer_code)
      end

      it "denies access to accountant" do
        seller_context = SellerContext.new(user: accountant_for_seller, seller:)
        expect(subject).to_not permit(seller_context, offer_code)
      end

      it "denies access to admin" do
        seller_context = SellerContext.new(user: admin_for_seller, seller:)
        expect(subject).to_not permit(seller_context, offer_code)
      end

      it "denies access to marketing" do
        seller_context = SellerContext.new(user: marketing_for_seller, seller:)
        expect(subject).to_not permit(seller_context, offer_code)
      end

      it "denies access to support" do
        seller_context = SellerContext.new(user: support_for_seller, seller:)
        expect(subject).not_to permit(seller_context, offer_code)
      end
    end
  end
end

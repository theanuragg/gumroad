# frozen_string_literal: true

require "spec_helper"

describe CollaboratorPolicy do
  subject { described_class }

  let(:admin_for_seller) { create(:user) }
  let(:accountant_for_seller) { create(:user) }
  let(:marketing_for_seller) { create(:user) }
  let(:support_for_seller) { create(:user) }
  let(:seller) { create(:named_seller) }

  before do
    create(:team_membership, user: admin_for_seller, seller:, role: TeamMembership::ROLE_ADMIN)
    create(:team_membership, user: accountant_for_seller, seller:, role: TeamMembership::ROLE_ACCOUNTANT)
    create(:team_membership, user: marketing_for_seller, seller:, role: TeamMembership::ROLE_MARKETING)
    create(:team_membership, user: support_for_seller, seller:, role: TeamMembership::ROLE_SUPPORT)
  end

  permissions :index?, :new?, :create?, :edit?, :update? do
    it "grants access to owner" do
      seller_context = SellerContext.new(user: seller, seller:)
      expect(subject).to permit(seller_context, Collaborator)
    end

    it "grants access to admin" do
      seller_context = SellerContext.new(user: admin_for_seller, seller:)
      expect(subject).to permit(seller_context, Collaborator)
    end

    it "denies access to accounting" do
      seller_context = SellerContext.new(user: accountant_for_seller, seller:)
      expect(subject).not_to permit(seller_context, Collaborator)
    end

    it "denies access to marketing" do
      seller_context = SellerContext.new(user: marketing_for_seller, seller:)
      expect(subject).not_to permit(seller_context, Collaborator)
    end

    it "denies access to support" do
      seller_context = SellerContext.new(user: support_for_seller, seller:)
      expect(subject).not_to permit(seller_context, Collaborator)
    end
  end

  permissions :destroy? do
    let!(:collaborator) { create(:collaborator, seller:) }

    context "when the collaborator belongs to the owner" do
      it "grants access to owner" do
        seller_context = SellerContext.new(user: seller, seller:)
        expect(subject).to permit(seller_context, collaborator)
      end

      it "grants access to admin" do
        seller_context = SellerContext.new(user: admin_for_seller, seller:)
        expect(subject).to permit(seller_context, collaborator)
      end

      it "denies access to accounting" do
        seller_context = SellerContext.new(user: accountant_for_seller, seller:)
        expect(subject).not_to permit(seller_context, collaborator)
      end

      it "denies access to marketing" do
        seller_context = SellerContext.new(user: marketing_for_seller, seller:)
        expect(subject).not_to permit(seller_context, collaborator)
      end

      it "denies access to support" do
        seller_context = SellerContext.new(user: support_for_seller, seller:)
        expect(subject).not_to permit(seller_context, collaborator)
      end
    end

    context "when the collaborator does not belong to the owner" do
      let(:collaborator) { create(:collaborator) }

      it "denies access to owner" do
        seller_context = SellerContext.new(user: seller, seller:)
        expect(subject).not_to permit(seller_context, collaborator)
      end

      it "denies access to admin" do
        seller_context = SellerContext.new(user: admin_for_seller, seller:)
        expect(subject).not_to permit(seller_context, collaborator)
      end

      it "denies access to accounting" do
        seller_context = SellerContext.new(user: accountant_for_seller, seller:)
        expect(subject).not_to permit(seller_context, collaborator)
      end

      it "denies access to marketing" do
        seller_context = SellerContext.new(user: marketing_for_seller, seller:)
        expect(subject).not_to permit(seller_context, collaborator)
      end

      it "denies access to support" do
        seller_context = SellerContext.new(user: support_for_seller, seller:)
        expect(subject).not_to permit(seller_context, collaborator)
      end
    end
  end
end

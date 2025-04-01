# frozen_string_literal: true

require "spec_helper"

describe CollaboratorsPresenter do
  describe "#index_props" do
    let(:seller) { create(:user) }
    let!(:collaborators) do
      [
        create(:collaborator, seller:, products: [create(:product, user: seller)]),
        create(:collaborator, seller:),
      ]
    end
    before { create(:collaborator, seller:, deleted_at: 1.day.ago) }

    it "returns the seller's live collaborators" do
      props = described_class.new(seller:).index_props

      expect(props).to match({
                               collaborators: collaborators.map do
                                 CollaboratorPresenter.new(seller:, collaborator: _1).collaborator_props
                               end,
                               collaborators_disabled_reason: nil,
                             })
    end

    it "returns collaborators supported as false if using a Brazilian Stripe Connect account" do
      brazilian_stripe_account = create(:merchant_account_stripe_connect, user: seller, country: "BR")
      seller.update!(check_merchant_account_is_linked: true)
      expect(seller.merchant_account(StripeChargeProcessor.charge_processor_id)).to eq brazilian_stripe_account

      props = described_class.new(seller:).index_props

      expect(props).to match({
                               collaborators: collaborators.map do
                                 CollaboratorPresenter.new(seller:, collaborator: _1).collaborator_props
                               end,
                               collaborators_disabled_reason: "Collaborators with Brazilian Stripe accounts are not supported.",
                             })
    end
  end
end

# frozen_string_literal: true

require "spec_helper"
require "shared_examples/receipt_presenter_concern"

describe ReceiptPresenter::ChargeInfo do
  let(:seller) { create(:named_seller) }
  let(:product) { create(:product, user: seller) }
  let(:purchase) do
    create(
      :purchase,
      link: product,
      seller:,
      price_cents: 14_99,
      created_at: DateTime.parse("January 1, 2023")
    )
  end
  let(:presenter) { described_class.new(chargeable, for_email: true, order_items_count: 1) }

  RSpec.shared_examples "chargeable" do
    describe "#formatted_created_at" do
      it "returns the formatted date" do
        expect(presenter.formatted_created_at).to eq("Jan 1, 2023")
      end
    end

    describe "#formatted_total_transaction_amount" do
      before do
        allow(chargeable).to receive(:charged_amount_cents).and_return(14_99)
      end

      context "when the purchase is not a membership" do
        it "returns formatted amount" do
          expect(presenter.formatted_total_transaction_amount).to eq("$14.99")
        end
      end
    end

    describe "#product_questions_note" do
      it "returns note with reply" do
        expect(presenter.product_questions_note).to eq(
          "Questions about your product? Contact Seller by replying to this email."
        )
      end

      context "when is not for email" do
        let(:presenter) { described_class.new(purchase, for_email: false, order_items_count: 1) }

        it "returns text with seller's email" do
          expect(presenter.product_questions_note).to eq(
            "Questions about your product? Contact Seller at <a href=\"mailto:seller@example.com\">seller@example.com</a>."
          )
        end
      end

      context "when is a gift sender purchase" do
        include_context "when is a gift sender purchase"

        RSpec.shared_examples "no product questions note for gift sender" do
          it "returns nil" do
            expect(presenter.product_questions_note).to be_nil
          end
        end

        describe "for a Purchase" do
          it_behaves_like "no product questions note for gift sender"
        end

        describe "for a Charge" do
          let(:charge) { create(:charge) }
          let(:payment_info) { described_class.new(charge) }
          let(:presenter) { described_class.new(charge, for_email: true, order_items_count: 1) }

          before do
            charge.purchases << purchase
            charge.order.purchases << purchase
          end

          it_behaves_like "no product questions note for gift sender"

          context "with multiple purchases" do
            let(:second_purchase) { create(:purchase) }

            before do
              charge.purchases << second_purchase
              charge.order.purchases << second_purchase
            end

            it_behaves_like "no product questions note for gift sender"
          end
        end
      end
    end
  end

  describe "for Purchase" do
    let(:chargeable) { purchase }

    it_behaves_like "chargeable"
  end

  describe "for Charge" do
    let(:charge) { create(:charge, seller:, purchases: [purchase], amount_cents: 14_99) }
    let!(:order) { charge.order }
    let(:chargeable) { charge }

    before do
      order.purchases << purchase
      order.update!(created_at: DateTime.parse("January 1, 2023"))
    end

    it_behaves_like "chargeable"
  end
end

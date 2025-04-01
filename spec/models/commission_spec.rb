# frozen_string_literal: true

describe Commission, :vcr do
  describe "validations" do
    it "validates inclusion of status in STATUSES" do
      commission = build(:commission, status: "invalid_status")
      expect(commission).to be_invalid
      expect(commission.errors.full_messages).to include("Status is not included in the list")
      commission.status = nil
      expect(commission).to be_invalid
      expect(commission.errors.full_messages).to include("Status is not included in the list")
    end

    it "validates presence of deposit_purchase" do
      commission = build(:commission, deposit_purchase: nil)
      expect(commission).to be_invalid
      expect(commission.errors.full_messages).to include("Deposit purchase must exist")
    end

    it "validates that deposit_purchase and completion_purchase are different" do
      purchase = create(:purchase)
      commission = build(:commission, deposit_purchase: purchase, completion_purchase: purchase)
      expect(commission).to be_invalid
      expect(commission.errors.full_messages).to include("Deposit purchase and completion purchase must be different purchases")
    end

    it "validates that deposit_purchase and completion_purchase belong to the same commission" do
      commission = build(:commission, deposit_purchase: create(:purchase, link: create(:product)), completion_purchase: create(:purchase, link: create(:product)))
      expect(commission).to be_invalid
      expect(commission.errors.full_messages).to include("Deposit purchase and completion purchase must belong to the same commission product")
    end

    it "validates that the purchased product is a commission" do
      product = create(:product, native_type: Link::NATIVE_TYPE_DIGITAL)
      commission = build(:commission, deposit_purchase: create(:purchase, link: product), completion_purchase: create(:purchase, link: product))
      expect(commission).to be_invalid
      expect(commission.errors.full_messages).to include("Purchased product must be a commission")
    end
  end

  describe "#create_completion_purchase!" do
    let!(:commission) { create(:commission, status: "in_progress") }

    context "when status is already completed" do
      it "does not create a completion purchase" do
        commission.update(status: Commission::STATUS_COMPLETED)
        expect { commission.create_completion_purchase! }.not_to change { Purchase.count }
      end
    end

    context "when status is not completed" do
      before do
        commission.deposit_purchase.update!(zip_code: "10001")
        commission.deposit_purchase.update!(displayed_price_cents: 100)
        commission.deposit_purchase.create_tip!(value_cents: 20)
        commission.deposit_purchase.variant_attributes << create(:variant, name: "Deluxe")
      end

      it "creates a completion purchase with correct attributes, processes it, and updates status" do
        deposit_purchase = commission.deposit_purchase

        expect { commission.create_completion_purchase! }.to change { Purchase.count }.by(1)

        completion_purchase = commission.reload.completion_purchase
        expect(completion_purchase.perceived_price_cents).to eq((deposit_purchase.price_cents / Commission::COMMISSION_DEPOSIT_PROPORTION) - deposit_purchase.price_cents)
        expect(completion_purchase.link).to eq(deposit_purchase.link)
        expect(completion_purchase.purchaser).to eq(deposit_purchase.purchaser)
        expect(completion_purchase.credit_card_id).to eq(deposit_purchase.credit_card_id)
        expect(completion_purchase.email).to eq(deposit_purchase.email)
        expect(completion_purchase.full_name).to eq(deposit_purchase.full_name)
        expect(completion_purchase.street_address).to eq(deposit_purchase.street_address)
        expect(completion_purchase.country).to eq(deposit_purchase.country)
        expect(completion_purchase.zip_code).to eq(deposit_purchase.zip_code)
        expect(completion_purchase.city).to eq(deposit_purchase.city)
        expect(completion_purchase.ip_address).to eq(deposit_purchase.ip_address)
        expect(completion_purchase.ip_state).to eq(deposit_purchase.ip_state)
        expect(completion_purchase.ip_country).to eq(deposit_purchase.ip_country)
        expect(completion_purchase.browser_guid).to eq(deposit_purchase.browser_guid)
        expect(completion_purchase.referrer).to eq(deposit_purchase.referrer)
        expect(completion_purchase.quantity).to eq(deposit_purchase.quantity)
        expect(completion_purchase.was_product_recommended).to eq(deposit_purchase.was_product_recommended)
        expect(completion_purchase.seller).to eq(deposit_purchase.seller)
        expect(completion_purchase.credit_card_zipcode).to eq(deposit_purchase.credit_card_zipcode)
        expect(completion_purchase.affiliate).to eq(deposit_purchase.affiliate.try(:alive?) ? deposit_purchase.affiliate : nil)
        expect(completion_purchase.offer_code).to eq(deposit_purchase.offer_code)
        expect(completion_purchase.is_commission_completion_purchase).to be true
        expect(completion_purchase.tip.value_cents).to eq(20)
        expect(completion_purchase.variant_attributes).to eq(deposit_purchase.variant_attributes)
        expect(completion_purchase).to be_successful

        expect(commission.reload.status).to eq(Commission::STATUS_COMPLETED)
      end

      context "when the completion purchase fails" do
        it "marks the purchase as failed" do
          expect(Stripe::PaymentIntent).to receive(:create).and_raise(Stripe::IdempotencyError)

          expect { commission.create_completion_purchase! }.to raise_error("Failed to create completion purchase")

          purchase = Purchase.last
          expect(purchase).to be_failed
          expect(purchase.is_commission_completion_purchase).to eq(true)
          expect(commission.reload.completion_purchase).to be_nil
        end
      end
    end
  end

  describe "#completion_price_cents" do
    let(:deposit_purchase) { create(:purchase, price_cents: 5000, is_commission_deposit_purchase: true) }
    let(:commission) { create(:commission, deposit_purchase: deposit_purchase) }

    it "returns the correct completion price" do
      expect(commission.completion_price_cents).to eq(5000)
    end
  end

  describe "statuses" do
    let(:commission) { build(:commission) }

    describe "#is_in_progress?" do
      it "returns true if the status is in_progress" do
        commission.status = Commission::STATUS_IN_PROGRESS
        expect(commission.is_in_progress?).to be true
      end

      it "returns false if the status is completed or cancelled" do
        commission.status = Commission::STATUS_COMPLETED
        expect(commission.is_in_progress?).to be false

        commission.status = Commission::STATUS_CANCELLED
        expect(commission.is_in_progress?).to be false
      end
    end

    describe "#is_completed?" do
      it "returns true if the status is completed" do
        commission.status = Commission::STATUS_COMPLETED
        expect(commission.is_completed?).to be true
      end

      it "returns false if the status is in_progress or cancelled" do
        commission.status = Commission::STATUS_IN_PROGRESS
        expect(commission.is_completed?).to be false

        commission.status = Commission::STATUS_CANCELLED
        expect(commission.is_completed?).to be false
      end
    end

    describe "#is_cancelled?" do
      it "returns true if the status is cancelled" do
        commission.status = Commission::STATUS_CANCELLED
        expect(commission.is_cancelled?).to be true
      end

      it "returns false if the status is in_progress or completed" do
        commission.status = Commission::STATUS_IN_PROGRESS
        expect(commission.is_cancelled?).to be false

        commission.status = Commission::STATUS_COMPLETED
        expect(commission.is_cancelled?).to be false
      end
    end
  end

  describe "#completion_display_price_cents" do
    let(:deposit_purchase) { create(:purchase, displayed_price_cents: 5000, is_commission_deposit_purchase: true) }
    let(:commission) { create(:commission, deposit_purchase: deposit_purchase) }

    it "returns the correct completion price" do
      expect(commission.completion_display_price_cents).to eq(5000)
    end
  end
end

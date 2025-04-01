# frozen_string_literal: true

require "spec_helper"

describe LowBalanceCheckJob do
  describe "#perform" do
    before do
      @creator = create(:user)
      @purchase = create(:refunded_purchase, link: create(:product, user: @creator))
    end

    context "when the unpaid balance is zero" do
      before do
        allow_any_instance_of(User).to receive(:unpaid_balance_cents).and_return(0)
      end

      it "doesn't disable refunds" do
        described_class.new.perform(@purchase.id)
        expect(@creator.reload.refunds_disabled?).to eq(false)
      end
    end

    context "when the unpaid balance is above the threshold (-$100)" do
      it "doesn't disable refunds" do
        allow_any_instance_of(User).to receive(:unpaid_balance_cents).and_return(-100_00)
        described_class.new.perform(@purchase.id)
        expect(@creator.reload.refunds_disabled?).to eq(false)
      end
    end

    context "when the unpaid balance is below the threshold (-$100)" do
      it "disables refunds" do
        allow_any_instance_of(User).to receive(:unpaid_balance_cents).and_return(-100_01)
        described_class.new.perform(@purchase.id)
        expect(@creator.reload.refunds_disabled?).to eq(true)
      end
    end
  end
end

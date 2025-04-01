# frozen_string_literal: true

describe SendPaypalTopupNotificationJob do
  describe "#perform" do
    before do
      seller = create(:user, unpaid_balance_cents: 152_279_86)
      seller2 = create(:user, unpaid_balance_cents: 215_145_32)
      create(:payment, state: "completed", txn_id: "txn_id_1", processor_fee_cents: 1, user: seller)
      create(:payment, state: "completed", txn_id: "txn_id_2", processor_fee_cents: 2, user: seller2)

      allow(Rails.env).to receive(:production?).and_return(true)
      allow(PaypalPayoutProcessor).to receive(:current_paypal_balance_cents).and_return(125_000_00)
    end

    it "sends a notification to slack with the required topup amount" do
      allow(PaypalPayoutProcessor).to receive(:topup_amount_in_transit).and_return(0)

      notification_msg = "PayPal balance needs to be $367,425.18 by Friday to payout all creators.\n"\
                       "Current PayPal balance is $125,000.\n"\
                       "A top-up of $242,425.18 is needed."

      described_class.new.perform

      expect(SlackMessageWorker).to have_enqueued_sidekiq_job("payments", "PayPal Top-up", notification_msg, "red")
    end

    it "includes details of payout amount in transit in the slack notification" do
      allow(PaypalPayoutProcessor).to receive(:topup_amount_in_transit).and_return(100_000)

      notification_msg = "PayPal balance needs to be $367,425.18 by Friday to payout all creators.\n"\
                       "Current PayPal balance is $125,000.\n"\
                       "Top-up amount in transit is $100,000.\n"\
                       "A top-up of $142,425.18 is needed."

      described_class.new.perform

      expect(SlackMessageWorker).to have_enqueued_sidekiq_job("payments", "PayPal Top-up", notification_msg, "red")
    end

    it "sends no more topup required green notification if there's sufficient amount in PayPal" do
      allow(PaypalPayoutProcessor).to receive(:topup_amount_in_transit).and_return(300_000)

      notification_msg = "PayPal balance needs to be $367,425.18 by Friday to payout all creators.\n"\
                       "Current PayPal balance is $125,000.\n"\
                       "Top-up amount in transit is $300,000.\n"\
                       "No more top-up required."

      described_class.new.perform

      expect(SlackMessageWorker).to have_enqueued_sidekiq_job("payments", "PayPal Top-up", notification_msg, "green")
    end
  end
end

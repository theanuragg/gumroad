# frozen_string_literal: true

require "spec_helper"

describe Purchase::Blockable do
  let(:product) { create(:product) }
  let(:buyer) { create(:user) }
  let(:purchase) { create(:purchase, link: product, email: "gumbot@gumroad.com", purchaser: buyer) }

  describe "#buyer_blocked?" do
    it "returns false when buyer is not blocked" do
      expect(purchase.buyer_blocked?).to eq(false)
    end

    context "when the purchase's browser is blocked" do
      before do
        BlockedObject.block!(BLOCKED_OBJECT_TYPES[:browser_guid], purchase.browser_guid, nil)
      end

      it "returns true" do
        expect(purchase.buyer_blocked?).to eq(true)
      end
    end

    context "when the purchase's email is blocked" do
      before do
        BlockedObject.block!(BLOCKED_OBJECT_TYPES[:email], purchase.email, nil)
      end

      it "returns true" do
        expect(purchase.buyer_blocked?).to eq(true)
      end
    end

    context "when the buyer's email address is blocked" do
      before do
        BlockedObject.block!(BLOCKED_OBJECT_TYPES[:email], buyer.email, nil)
      end

      it "returns true" do
        expect(purchase.buyer_blocked?).to eq(true)
      end
    end

    context "when the purchase's ip address is blocked" do
      before do
        BlockedObject.block!(BLOCKED_OBJECT_TYPES[:ip_address], purchase.ip_address, nil, expires_in: 1.hour)
      end

      it "returns true" do
        expect(purchase.buyer_blocked?).to eq(true)
      end
    end

    context "when the purchase's payment method is blocked" do
      before do
        BlockedObject.block!(BLOCKED_OBJECT_TYPES[:charge_processor_fingerprint], purchase.stripe_fingerprint, nil)
      end

      it "returns true" do
        expect(purchase.buyer_blocked?).to eq(true)
      end
    end
  end

  describe "#blocked_emails" do
    context "for a fraudulent transaction" do
      it "returns a list of blocked emails" do
        purchase = build(:purchase_in_progress,
                         email: "foo@example.com",
                         error_code: PurchaseErrorCode::FRAUD_RELATED_ERROR_CODES.sample)

        purchase.mark_failed!

        expect(purchase.blocked_emails).to eq ["foo@example.com"]
      end
    end

    context "for a non-fraudulent transaction" do
      it "returns an empty array" do
        purchase = build(:purchase_in_progress,
                         email: "foo@example.com",
                         error_code: "non_fraud_code")

        purchase.mark_failed!

        expect(purchase.blocked_emails).to be_empty
      end
    end
  end

  describe "#blocked_ip_addresses" do
    context "when purchase's ip address is not blocked" do
      it "returns an empty array" do
        expect(purchase.blocked_ip_addresses).to eq([])
      end
    end

    context "when purchase's ip address is blocked" do
      before do
        BlockedObject.block!(BLOCKED_OBJECT_TYPES[:ip_address], purchase.ip_address, nil, expires_in: 1.hour)
      end

      it "returns the blocked object values" do
        expect(purchase.blocked_ip_addresses).to contain_exactly(purchase.ip_address)
      end
    end
  end

  describe "#block_buyer!" do
    context "when the purchase is made through Stripe" do
      it "blocks buyer's email, browser_guid, ip_address and stripe_fingerprint" do
        purchase.block_buyer!

        [buyer.email, purchase.email, purchase.browser_guid, purchase.ip_address, purchase.stripe_fingerprint].each do |blocked_value|
          expect(BlockedObject.find_active_object(blocked_value).blocked?).to eq(true)
        end
      end
    end

    context "when the purchase is made through PayPal" do
      let(:paypal_chargeable) { build(:native_paypal_chargeable) }
      let(:purchase) { create(:purchase, card_visual: paypal_chargeable.visual, purchaser: buyer, chargeable: paypal_chargeable) }

      it "blocks buyer's email, browser_guid, ip_address and card_visual" do
        purchase.block_buyer!

        [buyer.email, purchase.email, purchase.browser_guid, purchase.ip_address, purchase.card_visual].each do |blocked_value|
          expect(BlockedObject.find_active_object(blocked_value).blocked?).to eq(true)
        end
      end
    end

    context "when blocking user is provided" do
      let(:admin_user) { create(:admin_user) }

      it "blocks buyer and references the blocker" do
        purchase.block_buyer!(blocking_user_id: admin_user.id)

        [buyer.email, purchase.email, purchase.browser_guid, purchase.ip_address, purchase.stripe_fingerprint].each do |blocked_value|
          BlockedObject.find_active_object(blocked_value).tap do |blocked_object|
            expect(blocked_object.blocked?).to eq(true)
            expect(blocked_object.blocked_by).to eq(admin_user.id)
          end
        end
      end

      it "sets `is_buyer_blocked_by_admin` to true" do
        expect(purchase.is_buyer_blocked_by_admin?).to eq(false)

        purchase.block_buyer!(blocking_user_id: admin_user.id)
        expect(purchase.is_buyer_blocked_by_admin?).to eq(true)
      end
    end

    describe "comments" do
      let(:admin_user) { create(:admin_user) }

      context "when comment content is provided" do
        it "adds buyer blocked comments with the provided content" do
          comment_content = "Blocked by Helper webhook"

          expect do
            purchase.block_buyer!(blocking_user_id: admin_user.id, comment_content:)
          end.to change { purchase.comments.where(content: comment_content, comment_type: "note", author_id: admin_user.id).count }.by(1)
             .and change { purchase.purchaser.comments.where(content: comment_content, comment_type: "note", author_id: admin_user.id, purchase:).count }.by(1)
        end
      end

      context "when comment content is not provided" do
        context "when the blocking user is an admin" do
          it "adds buyer blocked comments with the default content" do
            comment_content = "Buyer blocked by Admin (#{admin_user.email})"

            expect do
              purchase.block_buyer!(blocking_user_id: admin_user.id)
            end.to change { purchase.comments.where(content: comment_content, comment_type: "note", author_id: admin_user.id).count }.by(1)
               .and change { purchase.purchaser.comments.where(content: comment_content, comment_type: "note", author_id: admin_user.id, purchase:).count }.by(1)
          end
        end

        context "when the blocking user is not an admin" do
          it "adds buyer blocked comments with the default content" do
            user = create(:user)
            comment_content = "Buyer blocked by #{user.email}"

            expect do
              purchase.block_buyer!(blocking_user_id: user.id)
            end.to change { purchase.comments.where(content: comment_content, comment_type: "note", author_id: user.id).count }.by(1)
               .and change { purchase.purchaser.comments.where(content: comment_content, comment_type: "note", author_id: user.id, purchase:).count }.by(1)
          end
        end

        context "when the blocking user is not provided" do
          it "adds buyer blocked comments with the default content and GUMROAD_ADMIN as author" do
            comment_content = "Buyer blocked"

            expect do
              purchase.block_buyer!
            end.to change { purchase.comments.where(content: comment_content, comment_type: "note", author_id: GUMROAD_ADMIN_ID).count }.by(1)
               .and change { purchase.purchaser.comments.where(content: comment_content, comment_type: "note", author_id: GUMROAD_ADMIN_ID, purchase:).count }.by(1)
          end
        end
      end
    end
  end

  describe "#unblock_buyer!" do
    context "when buyer is not blocked" do
      it "does not call #unblock! on any blocked objects" do
        expect_any_instance_of(BlockedObject).to_not receive(:unblock!)
        purchase.unblock_buyer!
      end
    end

    context "when the purchase is made through Stripe" do
      it "unblocks the buyer's email, browser, IP address and stripe_fingerprint" do
        # Block purchase first to create the blocked objects
        purchase.block_buyer!

        purchase.unblock_buyer!
        [buyer.email, purchase.email, purchase.browser_guid, purchase.ip_address, purchase.stripe_fingerprint].each do |blocked_value|
          expect(BlockedObject.find_by(object_value: blocked_value).blocked?).to eq(false)
        end
      end
    end

    context "when the stripe_fingerprint is nil" do
      it "unblocks the buyer's stripe_fingerprint from a recent purchase" do
        purchase.block_buyer!

        purchase.update_attribute :stripe_fingerprint, nil

        recent_purchase = create(:purchase, purchaser: buyer, email: "gumbot@gumroad.com")

        expect do
          purchase.unblock_buyer!
        end.to change { BlockedObject.find_by(object_value: recent_purchase.stripe_fingerprint).blocked? }.from(true).to(false)
      end
    end

    context "when the purchase is made through PayPal" do
      let(:paypal_chargeable) { build(:native_paypal_chargeable) }
      let(:purchase) { create(:purchase, card_visual: paypal_chargeable.visual, purchaser: buyer, chargeable: paypal_chargeable) }

      it "unblocks the buyer's email, browser, IP address and card_visual" do
        # Block purchase first to create the blocked objects
        purchase.block_buyer!

        purchase.unblock_buyer!
        [buyer.email, purchase.email, purchase.browser_guid, purchase.ip_address, purchase.card_visual].each do |blocked_value|
          expect(BlockedObject.find_by(object_value: blocked_value).blocked?).to eq(false)
        end
      end
    end

    it "sets `is_buyer_blocked_by_admin` to false" do
      purchase.block_buyer!
      purchase.update!(is_buyer_blocked_by_admin: true)

      purchase.unblock_buyer!
      expect(purchase.is_buyer_blocked_by_admin).to eq(false)
    end
  end

  describe "#mark_failed" do
    context "when the purchase fails due to a fraud related reason" do
      let(:purchaser) { create(:user, email: "purchaser@example.com") }
      let(:purchase) { create(:purchase, purchaser:, email: "another-email@example.com", purchase_state: "in_progress", stripe_error_code: "card_declined_lost_card", charge_processor_id: StripeChargeProcessor.charge_processor_id) }
      let(:expected_blocked_objects) do [
        ["email", "purchaser@example.com"],
        ["browser_guid", purchase.browser_guid],
        ["email", "another-email@example.com"],
        ["ip_address", purchase.ip_address],
        ["charge_processor_fingerprint", purchase.stripe_fingerprint]
      ] end

      it "blocks buyer's email, browser_guid, ip_address and stripe_fingerprint" do
        expect do
          purchase.mark_failed
        end.to change { BlockedObject.count }.from(0).to(5)
        expect(BlockedObject.pluck(:object_type, :object_value)).to match_array(expected_blocked_objects)
      end
    end

    context "when the purchase fails due to a non-fraud related reason" do
      let(:purchase) { create(:purchase, purchase_state: "in_progress", stripe_error_code: "card_declined_expired_card", charge_processor_id: StripeChargeProcessor.charge_processor_id) }

      it "doesn't block buyer" do
        expect do
          purchase.mark_failed
        end.to_not change { BlockedObject.count }
      end
    end

    describe "ban card testers" do
      before do
        @purchaser = create(:user, email: "purchaser@example.com")
        Feature.activate(:ban_card_testers)
      end

      context "when previous failed purchases exist with same email or browser_guid but with different cards" do
        context "when previous failed purchases were made within the week" do
          before do
            3.times do |n|
              create(:failed_purchase, purchaser: @purchaser, email: @purchaser.email, stripe_fingerprint: SecureRandom.hex, created_at: n.days.ago)
            end

            @purchase = create(:purchase, purchaser: @purchaser, email: @purchaser.email, purchase_state: "in_progress", stripe_fingerprint: "hij", charge_processor_id: StripeChargeProcessor.charge_processor_id)

            @expected_blocked_objects = [
              ["email", @purchaser.email],
              ["browser_guid", @purchase.browser_guid],
              ["ip_address", @purchase.ip_address],
              ["charge_processor_fingerprint", @purchase.stripe_fingerprint]
            ]
          end

          it "blocks the buyer" do
            expect do
              @purchase.mark_failed!
            end.to change { BlockedObject.count }.from(0).to(4)
            expect(BlockedObject.pluck(:object_type, :object_value)).to match_array(@expected_blocked_objects)
          end
        end

        context "when previous failed purchases weren't made within the week" do
          before do
            3.times do |n|
              create(:failed_purchase, purchaser: @purchaser, email: @purchaser.email, stripe_fingerprint: SecureRandom.hex, created_at: (n + 7).days.ago)
            end

            @purchase = create(:purchase, purchaser: @purchaser, email: @purchaser.email, purchase_state: "in_progress", stripe_fingerprint: "hij", charge_processor_id: StripeChargeProcessor.charge_processor_id)
          end

          it "doesn't block buyer" do
            expect do
              @purchase.mark_failed!
            end.to_not change { BlockedObject.count }
          end
        end
      end

      context "when purchases with different cards fail from the same IP address" do
        context "when failures happen within a day" do
          before do
            3.times do |n|
              create(:failed_purchase, purchaser: @purchaser, ip_address: "192.168.1.1", stripe_fingerprint: SecureRandom.hex, created_at: n.hours.ago)
            end

            @purchase = create(:purchase, purchaser: @purchaser, ip_address: "192.168.1.1", purchase_state: "in_progress", stripe_fingerprint: "hij", charge_processor_id: StripeChargeProcessor.charge_processor_id)
          end

          context "when the ip_address is not already blocked" do
            it "blocks the IP address" do
              travel_to(Time.current) do
                expect do
                  @purchase.mark_failed!
                end.to change { BlockedObject.count }.from(0).to(1)

                expect(BlockedObject.pluck(:object_type, :object_value)).to eq [["ip_address", @purchase.ip_address]]
                expect(BlockedObject.ip_address.find_active_object(@purchase.ip_address).expires_at.to_i).to eq 7.days.from_now.to_i
              end
            end
          end

          context "when the ip_address is already blocked" do
            before do
              @expires_in = BlockedObject::IP_ADDRESS_BLOCKING_DURATION_IN_MONTHS.months

              BlockedObject.block!(
                BLOCKED_OBJECT_TYPES[:ip_address],
                @purchase.ip_address,
                nil,
                expires_in: @expires_in
              )
            end

            it "doesn't overwrite the previous ip_address block" do
              travel_to(Time.current) do
                expect do
                  @purchase.mark_failed!
                end.not_to change { BlockedObject.count }

                expect(BlockedObject.ip_address.find_active_object(@purchase.ip_address).expires_at.to_i).to eq @expires_in.from_now.to_i
              end
            end
          end
        end

        context "when failures doesn't happen in a day" do
          before do
            3.times do |n|
              create(:failed_purchase, purchaser: @purchaser, ip_address: "192.168.1.1", stripe_fingerprint: SecureRandom.hex, created_at: n.days.ago)
            end
            @purchase = create(:purchase, purchaser: @purchaser, ip_address: "192.168.1.1", purchase_state: "in_progress", stripe_fingerprint: "hij", charge_processor_id: StripeChargeProcessor.charge_processor_id)
          end

          it "doesn't block buyer" do
            expect do
              @purchase.mark_failed!
            end.to_not change { BlockedObject.count }
          end
        end
      end
    end

    describe "block purchases on product" do
      before do
        Feature.activate(:block_purchases_on_product)
        $redis.set(RedisKey.card_testing_product_watch_minutes, 5)
        $redis.set(RedisKey.card_testing_product_max_failed_purchases_count, 10)
        $redis.set(RedisKey.card_testing_product_block_hours, 1)
        @product = create(:product)
      end

      context "when number of failed purchases exceeds the threshold" do
        before do
          9.times do |n|
            create(:failed_purchase, link: @product)
          end
          @purchase = create(:purchase, link: @product, purchase_state: "in_progress")
        end

        context "when price is not zero" do
          it "blocks purchases on product" do
            travel_to(Time.current) do
              expect do
                @purchase.mark_failed!
              end.to change { BlockedObject.count }.from(0).to(1)

              expect(BlockedObject.pluck(:object_type, :object_value)).to eq [["product", @product.id.to_s]]
              expect(BlockedObject.product.find_active_object(@product.id).expires_at.to_i).to eq 1.hour.from_now.to_i
            end
          end
        end

        context "when price is zero" do
          before do
            @purchase = create(:purchase, price_cents: 0, link: @product, purchase_state: "in_progress")
          end

          it "doesn't block purchases on product" do
            travel_to(Time.current) do
              expect do
                @purchase.mark_failed!
              end.not_to change { BlockedObject.count }
            end
          end
        end

        context "when the error code belongs to IGNORED_ERROR_CODES list" do
          before do
            @purchase = create(:purchase, link: @product, purchase_state: "in_progress")
          end

          it "doesn't block purchases on product" do
            travel_to(Time.current) do
              expect do
                @purchase.error_code = PurchaseErrorCode::PERCEIVED_PRICE_CENTS_NOT_MATCHING
                @purchase.mark_failed!
              end.not_to change { BlockedObject.count }
            end
          end
        end
      end

      context "when number of failed purchases doesn't exceed the threshold" do
        before do
          create(:failed_purchase, link: @product)
          @purchase = create(:purchase, link: @product, purchase_state: "in_progress")
        end

        it "doesn't block purchases on product" do
          travel_to(Time.current) do
            expect do
              @purchase.mark_failed!
            end.not_to change { BlockedObject.count }
          end
        end
      end

      context "when multiple purchases fail in a row" do
        before do
          $redis.set(RedisKey.card_testing_max_number_of_failed_purchases_in_a_row, 3)
        end

        context "when all recent purchases were failed" do
          before do
            2.times do |n|
              create(:purchase, link: @product, purchase_state: "in_progress").mark_failed!
            end

            @purchase = create(:purchase, link: @product, purchase_state: "in_progress")
          end

          it "blocks purchases on product" do
            travel_to(Time.current) do
              expect do
                @purchase.mark_failed!
              end.to change { BlockedObject.count }.from(0).to(1)

              expect(BlockedObject.pluck(:object_type, :object_value)).to eq [["product", @product.id.to_s]]
              expect(BlockedObject.product.find_active_object(@product.id).expires_at.to_i).to eq 1.hour.from_now.to_i
            end
          end
        end

        context "when recent purchases fail with an error code from IGNORED_ERROR_CODES list" do
          before do
            2.times do |n|
              create(:purchase, link: @product, purchase_state: "in_progress", error_code: PurchaseErrorCode::PERCEIVED_PRICE_CENTS_NOT_MATCHING).mark_failed!
            end

            @purchase = create(:purchase, link: @product, purchase_state: "in_progress")
          end

          it "doesn't block purchases on product" do
            travel_to(Time.current) do
              expect do
                @purchase.mark_failed!
              end.not_to change { BlockedObject.count }
            end
          end
        end

        context "when a successful purchase exists in the recent purchases" do
          before do
            create(:purchase, link: @product, purchase_state: "in_progress").mark_failed!
            create(:purchase, link: @product, purchase_state: "in_progress").mark_failed!
            create(:purchase, link: @product, purchase_state: "in_progress").mark_successful!
            @purchase = create(:purchase, link: @product, purchase_state: "in_progress")
          end

          it "doesn't block purchases on product" do
            travel_to(Time.current) do
              expect do
                @purchase.mark_failed!
              end.not_to change { BlockedObject.count }
            end
          end
        end

        context "when a not_charged purchase exists in the recent purchases" do
          before do
            create(:purchase, link: @product, purchase_state: "in_progress").mark_failed!
            create(:purchase, link: @product, purchase_state: "in_progress").mark_failed!
            create(:purchase, link: @product, purchase_state: "in_progress").mark_not_charged!
            @purchase = create(:purchase, link: @product, purchase_state: "in_progress")
          end

          it "doesn't block purchases on product" do
            freeze_time do
              expect do
                @purchase.mark_failed!
              end.not_to change { BlockedObject.count }
            end
          end
        end
      end
    end
  end

  describe "#charge_processor_fingerprint" do
    context "when charge_processor_id is 'stripe'" do
      let(:purchase) { build(:purchase) }

      it "returns stripe fingerprint" do
        expect(purchase.charge_processor_fingerprint).to eq(purchase.stripe_fingerprint)
      end
    end

    context "when charge_processor_id is not 'stripe'" do
      let(:purchase) { build(:purchase, charge_processor_id: PaypalChargeProcessor.charge_processor_id, card_visual: "paypal-email@example.com") }

      it "returns card visual" do
        expect(purchase.charge_processor_fingerprint).to eq("paypal-email@example.com")
      end
    end
  end

  describe "#block_fraudulent_free_purchases!" do
    before do
      Feature.activate(:block_fraudulent_free_purchases)
      @product = create(:product, price_cents: 0)

      create_list(:purchase, 2, link: @product, ip_address: "127.0.0.1")
    end

    context "when number of free purchases of the same product from same IP address exceeds the threshold" do
      context "when the purchase happens within the configured time limit" do
        it "blocks the ip_address" do
          freeze_time do
            expect do
              purchase = create(:purchase, link: @product, ip_address: "127.0.0.1", purchase_state: "in_progress")
              purchase.mark_successful!
            end.to change { BlockedObject.count }.from(0).to(1)

            expect(BlockedObject.pluck(:object_type, :object_value)).to eq [["ip_address", "127.0.0.1"]]
            expect(BlockedObject.ip_address.find_active_object("127.0.0.1").expires_at.to_i).to eq 24.hours.from_now.to_i
          end
        end
      end

      context "when the purchase happens outside the configured time limit" do
        it "doesn't block the ip_address" do
          travel_to(5.hours.from_now) do
            expect do
              purchase = create(:purchase, link: @product, ip_address: "127.0.0.1", purchase_state: "in_progress")
              purchase.mark_successful!
            end.not_to change { BlockedObject.count }
          end
        end
      end
    end

    context "when the purchase is created for another product" do
      it "doesn't block the ip_address" do
        expect do
          purchase = create(:purchase, ip_address: "127.0.0.1", purchase_state: "in_progress")
          purchase.mark_successful!
        end.not_to change { BlockedObject.count }
      end
    end

    context "when the purchase is created from another ip_address" do
      it "doesn't block the ip_address" do
        expect do
          purchase = create(:purchase, link: @product, ip_address: "127.0.0.2", purchase_state: "in_progress")
          purchase.mark_successful!
        end.not_to change { BlockedObject.count }
      end
    end

    context "when purchase is not free" do
      it "doesn't block the ip_address" do
        expect do
          purchase = create(:purchase, price_cents: 100, link: @product, ip_address: "127.0.0.1", purchase_state: "in_progress")
          purchase.mark_successful!
        end.not_to change { BlockedObject.count }
      end
    end
  end

  describe "#suspend_buyer_on_fraudulent_card_decline!" do
    before do
      Feature.activate(:suspend_fraudulent_buyers)

      @buyer = create(:user)
      @purchase = build(:purchase_in_progress,
                        email: "sam@example.com",
                        error_code: PurchaseErrorCode::CARD_DECLINED_FRAUDULENT,
                        purchaser: @buyer)
    end

    context "when the error code is not CARD_DECLINED_FRAUDULENT" do
      it "doesn't suspend the buyer" do
        @purchase.error_code = PurchaseErrorCode::STRIPE_INSUFFICIENT_FUNDS

        expect { @purchase.mark_failed! }.not_to change { @buyer.reload.suspended? }
      end
    end

    context "when the buyer account was created more than 6 hours ago" do
      it "doesn't suspend the buyer" do
        @buyer.update!(created_at: 7.hours.ago)

        expect { @purchase.mark_failed! }.not_to change { @buyer.reload.suspended? }
      end
    end

    context "when the error code is CARD_DECLINED_FRAUDULENT" do
      context "when buyer account was created less than 6 hours ago" do
        it "suspends the buyer" do
          expect do
            @purchase.mark_failed!
            expect(@buyer.comments.last.author_name).to eq("fraudulent_purchases_blocker")
          end.to change { @buyer.reload.suspended? }.from(false).to(true)
        end
      end
    end
  end
end

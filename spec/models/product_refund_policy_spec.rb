# frozen_string_literal: true

require "spec_helper"

describe ProductRefundPolicy do
  let(:refund_policy) { create(:product_refund_policy) }

  describe "validations" do
    it "validates presence" do
      refund_policy = ProductRefundPolicy.new

      expect(refund_policy.valid?).to be false
      expect(refund_policy.errors.details[:seller].first[:error]).to eq :blank
      expect(refund_policy.errors.details[:product].first[:error]).to eq :blank
      expect(refund_policy.errors.details[:title].first[:error]).to eq :blank
    end

    context "when refund policy for product exists" do
      it "validates product uniqueness" do
        new_refund_policy = refund_policy.dup

        expect(new_refund_policy.valid?).to be false
        expect(new_refund_policy.errors.details[:product].first[:error]).to eq :taken
      end
    end

    it "validates title length" do
      refund_policy.title = "a" * 51
      expect(refund_policy.valid?).to be false
      expect(refund_policy.errors.details[:title].first[:error]).to eq :too_long
    end

    it "validates fine_print length" do
      refund_policy.fine_print = "a" * 3001
      expect(refund_policy.valid?).to be false
      expect(refund_policy.errors.details[:fine_print].first[:error]).to eq :too_long
    end

    it "strips tags" do
      refund_policy.title = "<h1>Refund policy</h1>"
      refund_policy.fine_print = "<p>This is a product-level refund policy</p>"
      refund_policy.save!

      expect(refund_policy.title).to eq "Refund policy"
      expect(refund_policy.fine_print).to eq "This is a product-level refund policy"
    end

    it "is invalid when the product belongs to the seller" do
      refund_policy = create(:product_refund_policy)
      refund_policy.product = create(:product)

      expect(refund_policy.valid?).to be false
      expect(refund_policy.errors.details[:product].first[:error]).to eq :invalid
    end
  end

  describe "stripped_fields" do
    it "strips leading and trailing spaces for title and fine_print" do
      refund_policy = create(:product_refund_policy, title: "  Refund policy  ", fine_print: "  This is a product-level refund policy  ")

      expect(refund_policy.title).to eq "Refund policy"
      expect(refund_policy.fine_print).to eq "This is a product-level refund policy"
    end

    it "nullifies fine_print" do
      refund_policy = create(:product_refund_policy, fine_print: "")

      expect(refund_policy.fine_print).to be_nil
    end
  end

  describe "#as_json" do
    let(:refund_policy) { create(:product_refund_policy) }

    it "returns a hash with refund details" do
      expect(refund_policy.as_json).to eq(
        {
          fine_print: refund_policy.fine_print,
          id: refund_policy.external_id,
          product_name: refund_policy.product.name,
          title: refund_policy.title,
        }
      )
    end
  end

  describe "scopes" do
    describe "for_visible_and_not_archived_products" do
      let!(:refund_policy_archived_product) { create(:product_refund_policy, product: create(:product, archived: true)) }
      let!(:refund_policy_deleted_product) { create(:product_refund_policy, product: create(:product, deleted_at: Time.current)) }
      let!(:refund_policy_product) { create(:product_refund_policy, product: create(:product)) }

      it "returns the correct record" do
        expect(ProductRefundPolicy.for_visible_and_not_archived_products).to eq [refund_policy_product]
      end
    end
  end

  describe "#no_refunds?" do
    let(:refund_policy) { create(:product_refund_policy) }

    it "returns true when title contains 'no refunds'" do
      refund_policy.title = "No refunds allowed"
      expect(refund_policy.no_refunds?).to be true
    end

    it "returns true when title contains 'final'" do
      refund_policy.title = "All sales final"
      expect(refund_policy.no_refunds?).to be true
    end

    it "returns true when title contains 'no returns'" do
      refund_policy.title = "No returns accepted"
      expect(refund_policy.no_refunds?).to be true
    end

    it "asks AI when title doesn't contain obvious no-refunds keywords", :vcr do
      refund_policy.title = "Custom policy"
      expect(refund_policy.no_refunds?).to be false
    end

    it "returns false when AI call fails" do
      refund_policy.title = "Custom policy"
      expect_any_instance_of(OpenAI::Client).to receive(:chat).and_raise(StandardError)
      expect(refund_policy.no_refunds?).to be false
    end
  end

  describe "#published_and_no_refunds?" do
    let(:refund_policy) { create(:product_refund_policy) }

    it "returns true when product is published and has no refunds" do
      allow(refund_policy.product).to receive(:published?).and_return(true)
      allow(refund_policy).to receive(:no_refunds?).and_return(true)
      expect(refund_policy.published_and_no_refunds?).to be true
    end

    it "returns false when product is not published" do
      allow(refund_policy.product).to receive(:published?).and_return(false)
      allow(refund_policy).to receive(:no_refunds?).and_return(true)
      expect(refund_policy.published_and_no_refunds?).to be false
    end

    it "returns false when refunds are allowed" do
      allow(refund_policy.product).to receive(:published?).and_return(true)
      allow(refund_policy).to receive(:no_refunds?).and_return(false)
      expect(refund_policy.published_and_no_refunds?).to be false
    end
  end
end

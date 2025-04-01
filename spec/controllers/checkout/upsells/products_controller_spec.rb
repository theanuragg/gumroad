# frozen_string_literal: true

require "spec_helper"

describe Checkout::Upsells::ProductsController do
  let(:seller) { create(:named_seller) }
  let!(:product1) { create(:product, :recommendable, user: seller, name: "Product 1", price_cents: 1000, price_currency_type: "usd", native_type: "digital") }
  let!(:product2) { create(:product, user: seller, name: "Product 2", price_cents: 2000, price_currency_type: "eur", native_type: "physical") }
  let!(:archived_product) { create(:product, user: seller, archived: true) }
  let!(:versioned_product) { create(:product_with_digital_versions, user: seller, name: "Versioned Product", price_cents: 3000) }
  let!(:membership_product) { create(:membership_product, user: seller, name: "Membership", price_cents: 4000) }

  describe "GET #index" do
    it "returns the seller's visible products" do
      sign_in seller
      get :index

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map(&:deep_symbolize_keys)).to eq(
        [
          {
            id: product1.external_id,
            name: "Product 1",
            permalink: product1.unique_permalink,
            price_cents: 1000,
            currency_code: "usd",
            review_count: 1,
            average_rating: 5.0,
            native_type: "digital"
          },
          {
            id: product2.external_id,
            name: "Product 2",
            permalink: product2.unique_permalink,
            price_cents: 2000,
            currency_code: "eur",
            review_count: 0,
            average_rating: 0.0,
            native_type: "physical"
          }
        ]
      )
    end

    context "with custom domain" do
      before do
        @request.host = "example.com"
        allow(controller).to receive(:user_by_domain).with("example.com").and_return(seller)
      end

      it "returns products for custom domain seller" do
        get :index

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.map(&:deep_symbolize_keys)).to eq(
          [
            {
              id: product1.external_id,
              name: "Product 1",
              permalink: product1.unique_permalink,
              price_cents: 1000,
              currency_code: "usd",
              review_count: 1,
              average_rating: 5.0,
              native_type: "digital"
            },
            {
              id: product2.external_id,
              name: "Product 2",
              permalink: product2.unique_permalink,
              price_cents: 2000,
              currency_code: "eur",
              review_count: 0,
              average_rating: 0.0,
              native_type: "physical"
            }
          ]
        )
      end
    end
  end

  describe "GET #show" do
    it "returns the requested visible product" do
      sign_in seller
      get :show, params: { id: product1.external_id }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.deep_symbolize_keys).to eq(
        {
          id: product1.external_id,
          name: "Product 1",
          permalink: product1.unique_permalink,
          price_cents: 1000,
          currency_code: "usd",
          review_count: 1,
          average_rating: 5.0,
          native_type: "digital"
        }
      )
    end

    it "raises ActiveRecord::RecordNotFound for an archived product" do
      sign_in seller
      expect do
        get :show, params: { id: archived_product.external_id }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "raises ActiveRecord::RecordNotFound for a non-existent product" do
      sign_in seller
      expect do
        get :show, params: { id: "non_existent_id" }
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end

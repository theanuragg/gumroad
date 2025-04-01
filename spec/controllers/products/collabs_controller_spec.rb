# frozen_string_literal: true

require "spec_helper"
require "shared_examples/sellers_base_controller_concern"
require "shared_examples/authorize_called"

describe Products::CollabsController, :vcr, :sidekiq_inline, :elasticsearch_wait_for_refresh do
  include CurrencyHelper
  render_views

  it_behaves_like "inherits from Sellers::BaseController"

  # User is a collaborator for two other sellers
  let(:user) { create(:user) }
  let(:pundit_user) { SellerContext.new(user:, seller: user) }

  let(:seller_1) { create(:user) }
  let(:seller_1_collaborator) { create(:collaborator, seller: seller_1, affiliate_user: user) }

  let(:seller_2) { create(:user) }
  let(:seller_2_collaborator) { create(:collaborator, seller: seller_2, affiliate_user: user) }

  # Products

  # 1. Owned by user
  let!(:collab_1) { create(:product, :is_collab, name: "Collab 1", user:, price_cents: 15_00, collaborator_cut: 50_00, created_at: 1.month.ago) }
  let!(:membership_collab_1) do
    create(:membership_product_with_preset_tiered_pricing, :is_collab, name: "Membership collab 1", user:, collaborator_cut: 50_00, created_at: 2.months.ago)
  end

  # 2. Owned by others
  let!(:collab_2) { create(:product, :is_collab, name: "Collab 2", user: seller_1, collaborator_cut: 25_00, collaborator: seller_1_collaborator, created_at: 3.months.ago) }
  let!(:collab_3) { create(:product, :is_collab, name: "Collab 3", user: seller_2, collaborator_cut: 50_00, collaborator: seller_2_collaborator, created_at: 4.months.ago) } # no purchases
  let!(:membership_collab_2) { create(:membership_product_with_preset_tiered_pricing, :is_collab, name: "Membership collab 2", user: seller_2, collaborator_cut: 25_00, collaborator: seller_2_collaborator, created_at: 5.months.ago) }

  # 3. Non-collab
  let!(:non_collab_product) { create(:product, user:) }
  let!(:affiliate_product) { create(:product, user:) }
  let!(:affiliate) { create(:direct_affiliate, seller: user, products: [affiliate_product]) }

  # Purchases

  # 1. For collabs
  let(:collab_1_purchase_1) { create(:purchase_in_progress, seller: user, link: collab_1, affiliate: collab_1.collaborator) }
  let(:collab_1_purchase_2) { create(:purchase_in_progress, seller: user, link: collab_1, affiliate: collab_1.collaborator) }
  let(:collab_1_purchase_3) { create(:purchase_in_progress, seller: user, link: collab_1, affiliate: collab_1.collaborator) }
  let(:collab_2_purchase_1) { create(:purchase_in_progress, seller: seller_1, link: collab_2, affiliate: collab_2.collaborator) }
  let(:collab_2_purchase_2) { create(:purchase_in_progress, seller: seller_1, link: collab_2, affiliate: collab_2.collaborator) }
  let(:collab_2_purchase_3) { create(:purchase_in_progress, seller: seller_1, link: collab_2, affiliate: collab_2.collaborator) }

  let(:membership_collab_1_purchase_1) do
    tier = membership_collab_1.tiers.first
    create(:membership_purchase, purchase_state: "in_progress", seller: user,
                                 link: membership_collab_1, price_cents: tier.prices.first.price_cents, # $3
                                 affiliate: membership_collab_1.collaborator, tier:)
  end
  let(:membership_collab_1_purchase_2) do
    tier = membership_collab_1.tiers.last
    create(:membership_purchase, purchase_state: "in_progress", seller: user,
                                 link: membership_collab_1, price_cents: tier.prices.first.price_cents, # $5
                                 affiliate: membership_collab_1.collaborator, tier:)
  end
  let(:membership_collab_2_purchase_1) do
    tier = membership_collab_2.tiers.last
    create(:membership_purchase, purchase_state: "in_progress", seller: seller_2,
                                 link: membership_collab_2, price_cents: tier.prices.first.price_cents, # $5
                                 affiliate: membership_collab_2.collaborator, tier:)
  end

  # 2. For non-collabs
  let(:non_collab_purchase) { create(:purchase_in_progress, seller: user, link: non_collab_product) }
  let(:affiliate_purchase) { create(:purchase_in_progress, seller: user, link: affiliate_product, affiliate:) }

  let(:successful_not_reversed_purchases) do
    [
      collab_1_purchase_1,
      collab_1_purchase_2,
      collab_1_purchase_3,
      collab_2_purchase_1,
      membership_collab_1_purchase_1,
      membership_collab_1_purchase_2,
      membership_collab_2_purchase_1,
    ]
  end

  let(:chargedback_purchase) { collab_2_purchase_2 }
  let(:failed_purchase) { collab_2_purchase_3 }

  before do
    purchases = successful_not_reversed_purchases + [chargedback_purchase, non_collab_purchase, affiliate_purchase]
    purchases.each do |purchase|
      purchase.process!
      purchase.update_balance_and_mark_successful!
    end

    # chargeback purchase
    allow_any_instance_of(Purchase).to receive(:fight_chargeback).and_return(true)
    event_flow_of_funds = FlowOfFunds.build_simple_flow_of_funds(Currency::USD, chargedback_purchase.total_transaction_cents)
    event = build(:charge_event_dispute_formalized, charge_id: chargedback_purchase.stripe_transaction_id, flow_of_funds: event_flow_of_funds)
    chargedback_purchase.handle_event_dispute_formalized!(event)
    chargedback_purchase.reload

    # failed purchase
    failed_purchase.mark_failed!
  end

  include_context "with user signed in as admin for seller" do
    let(:seller) { user }
  end

  it_behaves_like "authorize called for controller", Products::CollabsPolicy do
    let(:record) { :collabs }
  end

  describe "GET index" do
    it "renders collab products and stats" do
      get :index

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:index)

      # stats
      ["Total revenue", "$28", "Customers", "4", "Active members", "3", "Collaborations", "5"].each do |stat|
        expect(response.body).to include stat
      end

      # products
      [collab_1, collab_2, collab_3, membership_collab_1, membership_collab_2].each do |product|
        expect(response.body).to include product.name
      end
    end

    it "supports search by product name" do
      get :index, params: { query: "2" }

      expect(response).to have_http_status(:ok)
      expect(response).to render_template(:index)

      [collab_2, membership_collab_2].each do |product|
        expect(response.body).to include product.name
      end

      [collab_1, collab_3, membership_collab_1].each do |product|
        expect(response.body).not_to include product.name
      end
    end
  end

  describe "GET memberships_paged" do
    before { stub_const("CollabProductsPagePresenter::PER_PAGE", 1) }

    it "returns paginated membership collabs" do
      get :memberships_paged

      expect(response).to be_successful
      expect(response.parsed_body["entries"].map { _1["id"] }).to contain_exactly membership_collab_1.id
      expect(response.parsed_body["pagination"]).to match({ "page" => 1, "pages" => 2 })

      get :memberships_paged, params: { page: 2 }

      expect(response).to be_successful
      expect(response.parsed_body["entries"].map { _1["id"] }).to contain_exactly membership_collab_2.id
      expect(response.parsed_body["pagination"]).to match({ "page" => 2, "pages" => 2 })
    end
  end

  describe "GET products_paged" do
    before { stub_const("CollabProductsPagePresenter::PER_PAGE", 1) }

    it "returns paginated non-membership collabs" do
      get :products_paged

      expect(response).to be_successful
      expect(response.parsed_body["entries"].map { _1["id"] }).to contain_exactly collab_1.id
      expect(response.parsed_body["pagination"]).to match({ "page" => 1, "pages" => 3 })

      get :products_paged, params: { page: 2 }

      expect(response).to be_successful
      expect(response.parsed_body["entries"].map { _1["id"] }).to contain_exactly collab_2.id
      expect(response.parsed_body["pagination"]).to match({ "page" => 2, "pages" => 3 })
    end
  end
end

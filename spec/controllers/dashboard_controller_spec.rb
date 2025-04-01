# frozen_string_literal: true

require "spec_helper"
require "shared_examples/sellers_base_controller_concern"
require "shared_examples/authorize_called"

describe DashboardController do
  render_views

  it_behaves_like "inherits from Sellers::BaseController"

  let(:seller) { create(:named_user) }

  before do
    create(:user_compliance_info, user: seller, first_name: "Gumbot")
  end

  include_context "with user signed in as admin for seller"

  describe "GET index" do
    it_behaves_like "authorize called for action", :get, :index do
      let(:record) { :dashboard }
    end

    context "when seller has no activity" do
      it "renders the page" do
        get :index

        expect(response.body).to have_text("Hey, Gumbot! Welcome to Gumroad.")
        expect(response.body).to have_text("We're here to help you get paid for your work.")
        expect(response.body).to have_selector("a", text: "Create your first product")
        expect(response.body).to have_selector("a", text: "Make your first sale")
        expect(response.body).to_not have_text("Best selling")
      end
    end

    context "when seller has products, but no sales" do
      before do
        create(:product, user: seller)
      end

      it "renders no sales text" do
        get :index

        expect(response.body).to have_text("Best selling")
        expect(response.body).to have_text("You haven't made any sales yet. Learn how")
      end
    end

    context "when seller has purchases" do
      let(:product) { create(:product, user: seller, price_cents: 150) }
      let(:follower) { create(:follower, user: seller, confirmed_at: 7.hours.ago) }

      before do
        create(:purchase_event, purchase: create(:purchase, link: product), created_at: Time.current)
        follower.update!(confirmed_at: nil, deleted_at: 1.hour.ago)
      end

      around do |example|
        travel_to Time.utc(2023, 6, 4) do
          example.run
        end
      end

      it "renders the purchase", :sidekiq_inline, :elasticsearch_wait_for_refresh do
        get :index

        expect(response.body).to have_selector("h1", text: "Hey, Gumbot! Welcome back to Gumroad.")

        expect(response.body).to_not have_text("We're here to help you get paid for your work.")
        expect(response.body).to have_selector("s", text: "Create your first product")
        expect(response.body).to have_selector("s", text: "Make your first sale")

        expect(response.body).to have_table_row({ "Sales" => "1", "Revenue" => "$1.50", "Today" => "$1.50" })

        expect(response.body).to have_text "New sale of The Works of Edgar Gumstein for $1.50"
        expect(response.body).to have_text "New follower #{follower.email} added"
        expect(response.body).to have_text "Follower #{follower.email} removed"

        expect(response.body).to have_link(product.name, href: product.long_url)
      end
    end

    context "when seller has no alive products" do
      let(:product) { create(:product, user: seller) }

      before do
        product.delete!
      end

      it "renders appropriate text" do
        get :index

        expect(response.body).to have_text("We're here to help you get paid for your work.")
        expect(response.body).to have_selector("a", text: "Create your first product")
      end
    end

    context "when seller has completed all 'Getting started' items" do
      before do
        create(:product, user: seller)
        create(:workflow, seller:)
        create(:active_follower, user: seller)
        create(:purchase, :from_seller, seller:)
        create(:payment_completed, user: seller)
        create(:installment, seller:, send_emails: true)
      end

      it "doesn't render `Getting started` text"  do
        get :index

        expect(response.body).to_not have_text("We're here to help you get paid for your work.")
        expect(response.body).to_not have_text("Getting started")
      end
    end

    context "when seller is suspended for TOS" do
      let(:admin_user) { create(:user) }
      let!(:product) { create(:product, user: seller) }

      before do
        create(:user_compliance_info, user: seller)
        seller.flag_for_tos_violation(author_id: admin_user.id, product_id: product.id)
        seller.suspend_for_tos_violation(author_id: admin_user.id)
        # NOTE: The invalidate_active_sessions! callback from suspending the user, interferes
        # with the login mechanism, this is a hack get the `sign_in user` method work correctly
        request.env["warden"].session["last_sign_in_at"] = DateTime.current.to_i
      end

      it "redirects to the products_path" do
        get :index

        expect(response).to redirect_to products_path
      end
    end
  end

  describe "GET customers_count" do
    it_behaves_like "authorize called for action", :get, :customers_count do
      let(:record) { :dashboard }
    end

    it "returns the formatted number of customers" do
      allow_any_instance_of(User).to receive(:all_sales_count).and_return(123_456)

      get :customers_count

      expect(response).to be_successful
      expect(response.parsed_body["success"]).to eq(true)
      expect(response.parsed_body["value"]).to eq("123,456")
    end
  end

  describe "GET total_revenue" do
    it_behaves_like "authorize called for action", :get, :total_revenue do
      let(:record) { :dashboard }
    end

    it "returns the formatted revenue" do
      allow_any_instance_of(User).to receive(:gross_sales_cents_total_as_seller).and_return(123_456)

      get :total_revenue

      expect(response).to be_successful
      expect(response.parsed_body["success"]).to eq(true)
      expect(response.parsed_body["value"]).to eq("$1,234.56")
    end
  end

  describe "GET active_members_count" do
    it_behaves_like "authorize called for action", :get, :active_members_count do
      let(:record) { :dashboard }
    end

    it "returns the formatted revenue" do
      allow_any_instance_of(User).to receive(:active_members_count).and_return(123_456)

      get :active_members_count

      expect(response).to be_successful
      expect(response.parsed_body["success"]).to eq(true)
      expect(response.parsed_body["value"]).to eq("123,456")
    end
  end

  describe "GET monthly_recurring_revenue" do
    it_behaves_like "authorize called for action", :get, :monthly_recurring_revenue do
      let(:record) { :dashboard }
    end

    it "returns the formatted revenue" do
      allow_any_instance_of(User).to receive(:monthly_recurring_revenue).and_return(123_456)

      get :monthly_recurring_revenue

      expect(response).to be_successful
      expect(response.parsed_body["success"]).to eq(true)
      expect(response.parsed_body["value"]).to eq("$1,234.56")
    end
  end

  describe "GET download_tax_form" do
    it_behaves_like "authorize called for action", :get, :download_tax_form do
      let(:record) { :dashboard }
    end

    it "redirects to the 1099 form download url if present" do
      allow_any_instance_of(User).to receive(:tax_form_1099_download_url).and_return("https://gumroad.com/")

      get :download_tax_form

      expect(response).to redirect_to("https://gumroad.com/")
    end

    it "redirects to dashboard if form download url is not present" do
      allow_any_instance_of(User).to receive(:tax_form_1099_download_url).and_return(nil)

      get :download_tax_form

      expect(response).to redirect_to(dashboard_url(host: UrlService.domain_with_protocol))
      expect(flash[:alert]).to eq("A 1099 form for #{Time.current.prev_year.year} was not filed for your account.")
    end
  end
end

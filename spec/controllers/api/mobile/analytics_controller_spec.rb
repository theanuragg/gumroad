# frozen_string_literal: true

require "spec_helper"
require "shared_examples/paginated_api"

describe Api::Mobile::AnalyticsController do
  before do
    @app = create(:oauth_application, owner: create(:user))
    @user = create(:user, timezone: "UTC", created_at: Time.utc(2019))
    @params = {
      mobile_token: Api::Mobile::BaseController::MOBILE_TOKEN,
      access_token: create("doorkeeper/access_token", application: @app, resource_owner_id: @user.id, scopes: "creator_api").token
    }
  end

  describe "GET data_by_date" do
    before do
      @purchase = create(:purchase, link: build(:product, user: @user))
      index_model_records(Purchase)
    end

    it "returns data generated by the service" do
      get :data_by_date, params: @params.merge(range: "month")

      expect(response.parsed_body).to eq(
        "formatted_revenue" => "$1",
        "purchases" => [JSON.load(@purchase.as_json(creator_app_api: true).to_json)],
        "revenue" => 100,
        "sales_count" => 1,
      )
    end
  end

  describe "GET revenue_totals" do
    before do
      create(:purchase, link: build(:product, user: @user))
      index_model_records(Purchase)
    end

    it "returns data generated by the service" do
      expect(SellerMobileAnalyticsService).to receive(:new).with(@user, range: "day").and_call_original
      expect(SellerMobileAnalyticsService).to receive(:new).with(@user, range: "week").and_call_original
      expect(SellerMobileAnalyticsService).to receive(:new).with(@user, range: "month").and_call_original
      expect(SellerMobileAnalyticsService).to receive(:new).with(@user, range: "year").and_call_original

      get :revenue_totals, params: @params

      expect(response.parsed_body).to eq(
        "day" => { "formatted_revenue" => "$1", "revenue" => 100 },
        "week" => { "formatted_revenue" => "$1", "revenue" => 100 },
        "month" => { "formatted_revenue" => "$1", "revenue" => 100 },
        "year" => { "formatted_revenue" => "$1", "revenue" => 100 }
      )
    end
  end

  shared_examples "supports a date range" do |action_name|
    it "parses :date_range and assigns @start_date and @end_date" do
      @user.update!(timezone: "Eastern Time (US & Canada)", created_at: Time.utc(2015, 1, 2))
      travel_to Time.utc(2021, 6, 16) do
        get action_name, params: @params.merge(date_range: "1d")
        expect(assigns(:start_date)).to eq(Date.new(2021, 6, 15))
        expect(assigns(:end_date)).to eq(Date.new(2021, 6, 15))

        get action_name, params: @params.merge(date_range: "1w")
        expect(assigns(:start_date)).to eq(Date.new(2021, 6, 9))
        expect(assigns(:end_date)).to eq(Date.new(2021, 6, 15))

        get action_name, params: @params.merge(date_range: "1m")
        expect(assigns(:start_date)).to eq(Date.new(2021, 5, 17))
        expect(assigns(:end_date)).to eq(Date.new(2021, 6, 15))

        get action_name, params: @params.merge(date_range: "1y")
        expect(assigns(:start_date)).to eq(Date.new(2020, 6, 16))
        expect(assigns(:end_date)).to eq(Date.new(2021, 6, 15))

        get action_name, params: @params.merge(date_range: "all")
        expect(assigns(:start_date)).to eq(Date.new(2011, 4, 4))
        expect(assigns(:end_date)).to eq(Date.new(2021, 6, 15))
      end
    end

    it "parses :start_date and end_date and assigns @start_date and @end_date" do
      get action_name, params: @params.merge(start_date: "2021-01-01", end_date: "2021-06-16")
      expect(assigns(:start_date)).to eq(Date.new(2021, 1, 1))
      expect(assigns(:end_date)).to eq(Date.new(2021, 6, 16))
    end

    it "automatically assigns @start_date and @end_date if they're not set" do
      @user.update!(timezone: "Eastern Time (US & Canada)")
      travel_to Time.utc(2021, 6, 16) do
        get action_name, params: @params
        expect(assigns(:start_date)).to eq(Date.new(2021, 5, 17))
        expect(assigns(:end_date)).to eq(Date.new(2021, 6, 15))
      end
    end
  end

  describe "GET by_date" do
    before { create(:product, user: @user) }
    it_behaves_like "supports a date range", :by_date

    it "returns data generated by the service" do
      expected_response_body = CreatorAnalytics::CachingProxy.new(@user).data_for_dates(29.days.ago.to_date, Date.today, by: :date, options: { group_by: "day", days_without_years: true })
      get :by_date, params: @params # implicitely sets group_by to "day"
      expect(response.parsed_body).to equal_with_indifferent_access(expected_response_body)

      params = @params.deep_dup
      params[:group_by] = "day"
      get(:by_date, params:) # also supports explicit group_by = day
      expect(response.parsed_body).to equal_with_indifferent_access(expected_response_body)

      expected_response_body = CreatorAnalytics::CachingProxy.new(@user).data_for_dates(29.days.ago.to_date, Date.today, by: :date, options: { group_by: "month", days_without_years: true })
      params = @params.deep_dup
      params[:group_by] = "month"
      get(:by_date, params:)
      expect(response.parsed_body).to equal_with_indifferent_access(expected_response_body)
    end
  end

  describe "GET by_state" do
    before { create(:product, user: @user) }
    it_behaves_like "supports a date range", :by_state

    it "returns data generated by the service" do
      expected_response_body = CreatorAnalytics::CachingProxy.new(@user).data_for_dates(29.days.ago.to_date, Date.today, by: :state)
      get :by_state, params: @params
      expect(response.parsed_body).to equal_with_indifferent_access(expected_response_body)
    end
  end

  describe "GET by_referral" do
    before { create(:product, user: @user) }
    it_behaves_like "supports a date range", :by_referral

    it "returns data generated by the service" do
      expected_response_body = CreatorAnalytics::CachingProxy.new(@user).data_for_dates(29.days.ago.to_date, Date.today, by: :referral, options: { group_by: "day", days_without_years: true })
      get :by_referral, params: @params # implicitely sets group_by to "day"
      expect(response.parsed_body).to equal_with_indifferent_access(expected_response_body)

      params = @params.deep_dup
      params[:group_by] = "day"
      get(:by_referral, params:) # also supports explicit group_by = day
      expect(response.parsed_body).to equal_with_indifferent_access(expected_response_body)

      expected_response_body = CreatorAnalytics::CachingProxy.new(@user).data_for_dates(29.days.ago.to_date, Date.today, by: :referral, options: { group_by: "month", days_without_years: true })
      params = @params.deep_dup
      params[:group_by] = "month"
      get(:by_referral, params:)
      expect(response.parsed_body).to equal_with_indifferent_access(expected_response_body)
    end
  end

  describe "GET products" do
    it_behaves_like "a paginated API" do
      before do
        @action = :products
        @response_key_name = "products"
        @records = create_list(:product, 2, user: @user)
      end
    end

    it "returns list of products, ordered by the most recent" do
      products = create_list(:product, 2, user: @user)

      get :products, params: @params

      returned_products = response.parsed_body["products"]
      expect(returned_products.size).to eq(2)

      last_product = products.last
      expect(returned_products.first).to include(
        "name" => last_product.name,
        "unique_permalink" => last_product.unique_permalink,
      )
    end
  end
end

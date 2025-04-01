# frozen_string_literal: true

require "spec_helper"

describe GenerateQuarterlySalesReportJob do
  let (:country_code) { "GB" }
  let(:quarter) { 1 }
  let (:year) { 2015 }

  it "raises an argument error if the year is out of bounds" do
    expect { described_class.new.perform(country_code, quarter, 2013) }.to raise_error(ArgumentError)
  end

  it "raises an argument error if the month is out of bounds" do
    expect { described_class.new.perform(country_code, 13, year) }.to raise_error(ArgumentError)
  end

  it "raises an argument error if the country code is not valid" do
    expect { described_class.new.perform("AUS", quarter, year) }.to raise_error(ArgumentError)
  end

  describe "happy case", :vcr do
    let(:s3_bucket_double) do
      s3_bucket_double = double
      allow(Aws::S3::Resource).to receive_message_chain(:new, :bucket).and_return(s3_bucket_double)
      s3_bucket_double
    end

    before :context do
      @s3_object = Aws::S3::Resource.new.bucket("gumroad-specs").object("specs/international-sales-reporting-spec-#{SecureRandom.hex(18)}.zip")
    end

    before do
      travel_to(Time.zone.local(2015, 1, 1)) do
        product = create(:product, price_cents: 100_00, native_type: "digital")

        @purchase1 = create(:purchase_in_progress, link: product, country: "United Kingdom")
        @purchase2 = create(:purchase_in_progress, link: product, country: "Australia")
        @purchase3 = create(:purchase_in_progress, link: product, country: "United Kingdom")
        @purchase4 = create(:purchase_in_progress, link: product, country: "Singapore")
        @purchase5 = create(:purchase_in_progress, link: product, country: "United Kingdom")

        Purchase.in_progress.find_each do |purchase|
          purchase.chargeable = create(:chargeable)
          purchase.process!
          purchase.update_balance_and_mark_successful!
        end
      end
    end

    it "creates a CSV file for sales into the United Kingdom" do
      expect(s3_bucket_double).to receive(:object).ordered.and_return(@s3_object)

      described_class.new.perform(country_code, quarter, year)

      expect(SlackMessageWorker).to have_enqueued_sidekiq_job("payments", "VAT Reporting", anything, "green")

      temp_file = Tempfile.new("actual-file", encoding: "ascii-8bit")
      @s3_object.get(response_target: temp_file)
      temp_file.rewind
      actual_payload = CSV.read(temp_file)

      expect(actual_payload.length).to eq(4)
      expect(actual_payload[0]).to eq(["Sale time", "Sale ID",
                                       "Seller ID", "Seller Email",
                                       "Seller Country",
                                       "Buyer Email", "Buyer Card",
                                       "Price", "Gumroad Fee", "GST",
                                       "Shipping", "Total"])

      expect(actual_payload[1]).to eq(["2015-01-01 00:00:00 UTC", @purchase1.external_id,
                                       @purchase1.seller.external_id, @purchase1.seller.form_email&.gsub(/.{0,4}@/, '####@'),
                                       nil,
                                       @purchase1.email&.gsub(/.{0,4}@/, '####@'), "**** **** **** 4242",
                                       "10000", "1370", "0",
                                       "0", "10000"])

      expect(actual_payload[2]).to eq(["2015-01-01 00:00:00 UTC", @purchase3.external_id,
                                       @purchase3.seller.external_id, @purchase3.seller.form_email&.gsub(/.{0,4}@/, '####@'),
                                       nil,
                                       @purchase3.email&.gsub(/.{0,4}@/, '####@'), "**** **** **** 4242",
                                       "10000", "1370", "0",
                                       "0", "10000"])

      expect(actual_payload[3]).to eq(["2015-01-01 00:00:00 UTC", @purchase5.external_id,
                                       @purchase5.seller.external_id, @purchase5.seller.form_email&.gsub(/.{0,4}@/, '####@'),
                                       nil,
                                       @purchase5.email&.gsub(/.{0,4}@/, '####@'), "**** **** **** 4242",
                                       "10000", "1370", "0",
                                       "0", "10000"])
    end

    it "creates a CSV file for sales into Australia" do
      expect(s3_bucket_double).to receive(:object).ordered.and_return(@s3_object)

      described_class.new.perform("AU", quarter, year)

      expect(SlackMessageWorker).to have_enqueued_sidekiq_job("payments", "GST Reporting", anything, "green")

      temp_file = Tempfile.new("actual-file", encoding: "ascii-8bit")
      @s3_object.get(response_target: temp_file)
      temp_file.rewind
      actual_payload = CSV.read(temp_file)

      expect(actual_payload.length).to eq(2)
      expect(actual_payload[0]).to eq(["Sale time", "Sale ID",
                                       "Seller ID", "Seller Email",
                                       "Seller Country",
                                       "Buyer Email", "Buyer Card",
                                       "Price", "Gumroad Fee", "GST",
                                       "Shipping", "Total",
                                       "Direct-To-Customer / Buy-Sell", "Zip Tax Rate ID", "Customer ABN Number"])

      expect(actual_payload[1]).to eq(["2015-01-01 00:00:00 UTC", @purchase2.external_id,
                                       @purchase2.seller.external_id, @purchase2.seller.form_email&.gsub(/.{0,4}@/, '####@'),
                                       nil,
                                       @purchase2.email&.gsub(/.{0,4}@/, '####@'), "**** **** **** 4242",
                                       "10000", "1370", "0",
                                       "0", "10000",
                                       "BS", nil, nil])
    end

    it "creates a CSV file for sales into Singapore" do
      expect(s3_bucket_double).to receive(:object).ordered.and_return(@s3_object)

      described_class.new.perform("SG", quarter, year)

      expect(SlackMessageWorker).to have_enqueued_sidekiq_job("payments", "GST Reporting", anything, "green")

      temp_file = Tempfile.new("actual-file", encoding: "ascii-8bit")
      @s3_object.get(response_target: temp_file)
      temp_file.rewind
      actual_payload = CSV.read(temp_file)

      expect(actual_payload.length).to eq(2)
      expect(actual_payload[0]).to eq(["Sale time", "Sale ID",
                                       "Seller ID", "Seller Email",
                                       "Seller Country",
                                       "Buyer Email", "Buyer Card",
                                       "Price", "Gumroad Fee", "GST",
                                       "Shipping", "Total",
                                       "Direct-To-Customer / Buy-Sell", "Zip Tax Rate ID", "Customer GST Number"])

      expect(actual_payload[1]).to eq(["2015-01-01 00:00:00 UTC", @purchase4.external_id,
                                       @purchase4.seller.external_id, @purchase4.seller.form_email&.gsub(/.{0,4}@/, '####@'),
                                       nil,
                                       @purchase4.email&.gsub(/.{0,4}@/, '####@'), "**** **** **** 4242",
                                       "10000", "1370", "0",
                                       "0", "10000",
                                       "BS", nil, nil])
    end
  end
end

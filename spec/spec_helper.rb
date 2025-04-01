# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
BUILDING_ON_CI = !ENV["CI"].nil?

require File.expand_path("../config/environment", __dir__)

require "capybara/rails"
require "capybara/rspec"
require "rspec/rails"
require "paper_trail/frameworks/rspec"
require "pundit/rspec"
Dir.glob(Rails.root.join("spec", "support", "**", "*.rb")).each { |f| require f }

JsonMatchers.schema_root = "spec/support/schemas"

KnapsackPro::Adapters::RSpecAdapter.bind

ActiveRecord::Migration.maintain_test_schema!

# Capybara settings
Capybara.test_id = "data-testid"
Capybara.default_max_wait_time = 25
Capybara.app_host = "#{PROTOCOL}://#{DOMAIN}"
Capybara.server = :puma
Capybara.server_port = URI(Capybara.app_host).port
Capybara.threadsafe = true
Capybara.enable_aria_label = true
Capybara.enable_aria_role = true

FactoryBot.definition_file_paths << Rails.root.join("spec", "support", "factories")
Mongoid.load!(Rails.root.join("config", "mongoid.yml"))
Braintree::Configuration.logger = Logger.new(File::NULL)
PayPal::SDK.logger = Logger.new(File::NULL)

unless BUILDING_ON_CI
  # super_diff error formatting doesn't work well on CI, and for flaky Capybara specs it can potentially obfuscate the actual error
  require "super_diff/rspec-rails"
  SuperDiff.configure { |config| config.actual_color = :green }
end

# NOTE Add only valid errors here. Do not errors we should handle and fix on specs themselves
JSErrorReporter.set_global_ignores [
  /(Component closed|Object|zoid destroyed all components)\n\t \(https:\/\/www.paypal.com\/sdk\/js/,
  /The method FB.getLoginStatus can no longer be called from http pages/,
  /The user aborted a request./,
]

def configure_vcr
  VCR.configure do |config|
    config.cassette_library_dir = File.join(Rails.root, "spec", "support", "fixtures", "vcr_cassettes")
    config.hook_into :webmock
    config.ignore_hosts "gumroad-specs.s3.amazonaws.com", "s3.amazonaws.com", "codeclimate.com", "mongo", "redis", "elasticsearch"
    config.ignore_hosts "api.knapsackpro.com"
    config.ignore_hosts "googlechromelabs.github.io"
    config.ignore_hosts "storage.googleapis.com"
    config.ignore_localhost = true
    config.configure_rspec_metadata!
    config.debug_logger = $stdout if ENV["VCR_DEBUG"]
    config.default_cassette_options[:record] = BUILDING_ON_CI ? :none : :once
  end
end

configure_vcr

def prepare_mysql
  ActiveRecord::Base.connection.execute("SET SESSION information_schema_stats_expiry = 0")
  DatabaseCleaner[:active_record].clean_with(:truncation, pre_count: true)
end

RSpec.configure do |config|
  config.include Capybara::DSL
  config.include ErrorResponses
  config.mock_with :rspec
  config.file_fixture_path = "#{::Rails.root}/spec/support/fixtures"
  config.infer_base_class_for_anonymous_controllers = false
  config.infer_spec_type_from_file_location!
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :helper
  config.include FactoryBot::Syntax::Methods
  config.pattern = "**/*_spec.rb"
  config.raise_errors_for_deprecations!
  config.use_transactional_fixtures = false
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = Rails.root.join("tmp", "rspec_status.txt").to_s
  config.include ActiveSupport::Testing::TimeHelpers

  if BUILDING_ON_CI
    # show retry status in spec process
    config.verbose_retry = true
    # show exception that triggers a retry if verbose_retry is set to true
    config.display_try_failure_messages = true
    config.default_retry_count = 3
  end
  config.before(:suite) do
    # Disable webmock while cleanup, see also https://github.com/teamcapybara/capybara#gotchas
    WebMock.allow_net_connect!(net_http_connect_on_start: true)
    [
      Thread.new { prepare_mysql },
      Thread.new { ElasticsearchSetup.prepare_test_environment }
    ].each(&:join)
  end

  config.before(:all) do |example|
    $spec_example_start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    print "#{example.class.description}: "
  end
  config.after(:all) do
    spec_example_duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - $spec_example_start
    puts " [#{spec_example_duration.round(2)}s]"
  end

  # Differences between before/after and around: https://relishapp.com/rspec/rspec-core/v/3-0/docs/hooks/around-hooks
  # tldr: before/after will share state with the example, needed for some plugins
  config.before(:each) do
    Rails.application.load_seed
    DatabaseCleaner.start
    Sidekiq.redis(&:flushdb)
    $redis.flushdb
    %i[
      store_discover_searches
      log_email_events
      follow_wishlists
      seller_refund_policy_new_users_enabled
      merchant_of_record_fee
      paypal_payout_fee
    ].each do |feature|
      Feature.activate(feature)
    end
    @request&.host = DOMAIN # @request only valid for controller specs.
    PostSendgridApi.mails.clear
  end

  config.after(:each) do |example|
    capture_state_on_failure(example)
    Capybara.reset_sessions!
    DatabaseCleaner.clean
    WebMock.allow_net_connect!
  end

  config.around(:each) do |example|
    if example.metadata[:sidekiq_inline]
      Sidekiq::Testing.inline!
    else
      Sidekiq::Testing.fake!
    end
    example.run
  end

  config.around(:each, :elasticsearch_wait_for_refresh) do |example|
    actions = [:index, :update, :update_by_query, :delete]
    actions.each do |action|
      Elasticsearch::API::Actions.send(:alias_method, action, :"#{action}_and_wait_for_refresh")
    end
    example.run
    actions.each do |action|
      Elasticsearch::API::Actions.send(:alias_method, action, :"original_#{action}")
    end
  end

  config.around(:each, :freeze_time) do |example|
    freeze_time do
      example.run
    end
  end

  config.around(:each) do |example|
    config.instance_variable_set(:@curr_file_path, example.metadata[:example_group][:file_path])
    Mongoid.purge!
    options = %w[caching js] # delegate all the before- and after- hooks for these values to metaprogramming "setup" and "teardown" methods, below
    options.each { |opt| send(:"setup_#{ opt }", example.metadata[opt.to_sym]) }
    stub_webmock
    example.run
    options.each { |opt| send(:"teardown_#{ opt }", example.metadata[opt.to_sym]) }
    Rails.cache.clear
    travel_back
  end

  config.around(:each, :shipping) do |example|
    vcr_turned_on do
      only_matching_vcr_request_from(["easypost", "taxjar"]) do
        VCR.use_cassette("ShippingScenarios/#{example.description}", record: :once) do
          example.run
        end
      end
    end
  end

  config.around(:each, :taxjar) do |example|
    vcr_turned_on do
      only_matching_vcr_request_from(["taxjar"]) do
        VCR.use_cassette("Taxjar/#{example.description}", record: :once) do
          example.run
        end
      end
    end
  end

  config.after(:each, type: :feature, js: true) do
    JSErrorReporter.instance.report_errors!(self)
    JSErrorReporter.instance.reset!
  end

  config.before(:each) do
    # Needs to be a valid URL that returns 200 OK when accessed externally, otherwise requests to Stripe will error out.
    allow_any_instance_of(User).to receive(:business_profile_url).and_return("https://vipul.gumroad.com/")
  end

  # Subscribe Preview Generation boots up a new webdriver instance and uploads to S3 for each run.
  # This breaks CI because it collides with Capybara and spams S3, since it runs on User model changes.
  # The job and associated code is tested separately instead.
  config.before(:each) do
    allow_any_instance_of(User).to receive(:generate_subscribe_preview).and_return(true)
  end

  config.around(realistic_error_responses: true) do |example|
    respond_without_detailed_exceptions(&example)
  end
end

def ignore_js_error(string_or_regex)
  JSErrorReporter.instance.add_ignore_error string_or_regex
end

def capture_state_on_failure(example)
  return if example.exception.blank?

  suppress(Capybara::NotSupportedByDriverError) do
    save_path = example.metadata[:example_group][:location]
    Capybara.page.save_page("#{save_path}.html")
    Capybara.page.save_screenshot "#{save_path}.png"
  end
end

def find_and_click(selector, options = {})
  expect(page).to have_selector(selector, **options)
  page.find(selector, **options).click
end

def expect_alert_message(text)
  expect(page).to have_selector("[role=alert]", text:)
end

def expect_404_response(response)
  expect(response).to have_http_status(:not_found)
  expect(response.parsed_body["success"]).to eq(false)
  expect(response.parsed_body["error"]).to eq("Not found")
end

# Around filters for "setup" and "teardown" depending on test/suite options
def setup_caching(val = false)
  ActionController::Base.perform_caching = val
end

def setup_js(val = false)
  if val
    VCR.turn_off!
    # See also https://github.com/teamcapybara/capybara#gotchas
    WebMock.allow_net_connect!(net_http_connect_on_start: true)
    DatabaseCleaner[:active_record].strategy = :truncation, { pre_count: true, except: %w(taxonomies taxonomy_hierarchies) }
  else
    VCR.turn_on!
    WebMock.disable_net_connect!(allow_localhost: true, allow: ["api.knapsackpro.com"])
    DatabaseCleaner[:active_record].strategy = :transaction
  end
end

def teardown_caching(val = false)
  ActionController::Base.perform_caching = !val
end

def teardown_js(val = false)
  if val
    WebMock.disable_net_connect!(allow_localhost: true, allow: ["api.knapsackpro.com"])
    stub_webmock
  end
end

def run_with_log_level(log_level)
  previous_log_level = Rails.logger.level
  Rails.logger.level = log_level
  yield
ensure
  Rails.logger.level = previous_log_level
end

def vcr_turned_on
  prev_vcr_on = VCR.turned_on?
  VCR.turn_on! unless prev_vcr_on
  begin
    yield
  ensure
    VCR.turn_off! unless prev_vcr_on
  end
end

def only_matching_vcr_request_from(hosts)
  VCR.configure do |c|
    c.ignore_request do |request|
      !hosts.any? { |host| request.uri.match?(host) }
    end
  end

  begin
    yield
  ensure
    configure_vcr
  end
end

def stub_pwned_password_check
  @pwned_password_request_stub = WebMock.stub_request(:get, %r{api\.pwnedpasswords\.com/range/.+})
end

def stub_webmock
  WebMock.stub_request(:post, "https://notify.bugsnag.com/")
  WebMock.stub_request(:post, "https://sessions.bugsnag.com/")
  WebMock.stub_request(:post, %r{iffy-live\.gumroad\.com/people/buyer_info})
      .with(body: "{\"require_zip\": false}", headers: { status: %w[200 OK], content_type: "application/json" })
  stub_pwned_password_check
end

def with_real_pwned_password_check
  WebMock.remove_request_stub(@pwned_password_request_stub)

  begin
    yield
  ensure
    stub_pwned_password_check
  end
end

RSpec.configure do |config|
  config.include Devise::Test::IntegrationHelpers, type: :feature
  config.include CapybaraHelpers, type: :feature
  config.include ProductFileListHelpers, type: :feature
  config.include ProductCardHelpers, type: :feature
  config.include ProductRowHelpers, type: :feature
  config.include ProductVariantsHelpers, type: :feature
  config.include PreviewBoxHelpers, type: :feature
  config.include ProductWantThisHelpers, type: :feature
  config.include PayWorkflowHelpers, type: :feature
  config.include CheckoutHelpers, type: :feature
  config.include RichTextEditorHelpers, type: :feature
  config.include DiscoverHelpers, type: :feature
  config.include MockTableHelpers
  config.include SecureHeadersHelpers, type: :feature
  config.include ElasticsearchHelpers
  config.include ProductPageViewHelpers
  config.include SalesRelatedProductsInfosHelpers
end
RSpec::Sidekiq.configure do |config|
  config.warn_when_jobs_not_processed_by_sidekiq = false
end

RSpec::Mocks.configuration.allow_message_expectations_on_nil = true

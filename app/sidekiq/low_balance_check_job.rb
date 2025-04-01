# frozen_string_literal: true

class LowBalanceCheckJob
  include Sidekiq::Job
  sidekiq_options retry: 2, queue: :default

  def perform(purchase_id)
    creator = Purchase.find(purchase_id).seller
    puts "creator.unpaid_balance_cents: #{creator.unpaid_balance_cents}"
    return if creator.unpaid_balance_cents >= -10000

    creator.disable_refunds!
  end
end

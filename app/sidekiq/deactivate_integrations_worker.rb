# frozen_string_literal: true

class DeactivateIntegrationsWorker
  include Sidekiq::Job
  sidekiq_options retry: 5, queue: :default

  def perform(purchase_id)
    purchase = Purchase.find(purchase_id)

    [Integrations::CircleIntegrationService, Integrations::DiscordIntegrationService].each do |integration_service|
      integration_service.new.deactivate(purchase)
    rescue Discordrb::Errors::NoPermission => e
      Rails.logger.warn("DeactivateIntegrationsWorker: Permissions error for #{purchase.id} - #{e.class} => #{e.message}")
      next
    end
  end
end

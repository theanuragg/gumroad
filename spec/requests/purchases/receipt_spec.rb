# frozen_string_literal: true

require "spec_helper"

describe("Viewing a purchase receipt", type: :feature, js: true) do
  describe "membership purchase" do
    let(:purchase) { create(:membership_purchase) }
    let(:manage_membership_url) { Rails.application.routes.url_helpers.manage_subscription_url(purchase.subscription.external_id, host: "#{PROTOCOL}://#{DOMAIN}") }
    before { create(:url_redirect, purchase:) }

    it "requires email confirmation to access receipt page" do
      visit receipt_purchase_url(purchase.external_id, host: "#{PROTOCOL}://#{DOMAIN}")
      expect(page).to have_content("Confirm your email address")

      fill_in "Email address:", with: purchase.email
      click_button "View receipt"

      expect(page).to have_link "subscription settings", href: manage_membership_url
      expect(page).to have_link "Manage membership", href: manage_membership_url
    end

    it "shows error message when incorrect email is provided" do
      visit receipt_purchase_url(purchase.external_id, host: "#{PROTOCOL}://#{DOMAIN}")
      expect(page).to have_content("Confirm your email address")

      fill_in "Email address:", with: "wrong@example.com"
      click_button "View receipt"

      expect(page).to have_content("Wrong email. Please try again.")
      expect(page).to have_content("Confirm your email address")
    end
  end
end

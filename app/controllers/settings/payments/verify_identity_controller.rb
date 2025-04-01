# frozen_string_literal: true

class Settings::Payments::VerifyIdentityController < Sellers::BaseController
  def create
    authorize [:settings, :payments, current_seller], :verify_identity?

    unless current_seller.user_compliance_info_requests
                         .requested
                         .where(field_needed: UserComplianceInfoFields::Individual::STRIPE_ENHANCED_IDENTITY_VERIFICATION).exists?
      return render json: { success: false }
    end

    render json: { success: true, redirect_url: generate_stripe_verification_url }
  end

  def show
    authorize [:settings, :payments, current_seller], :verify_identity?

    stripe_account = Stripe::Account.retrieve(current_seller.stripe_account.charge_processor_merchant_id)

    if stripe_account["requirements"]["eventually_due"].include?("individual.verification.proof_of_liveness")
      flash[:alert] = "We weren't able to complete your identity verification. Please try again."
    else
      # We're marking the pending compliance request as provided on our end here if it is no longer due on Stripe.
      # We'll get a account.updated webhook event and mark these requests as provided there as well,
      # but doing it here instead of waiting on the webhook, so that the respective compliance request notice is removed
      # from the page immediately.
      user_compliance_info_requests = current_seller.user_compliance_info_requests
                                          .requested
                                          .where(field_needed: UserComplianceInfoFields::Individual::STRIPE_ENHANCED_IDENTITY_VERIFICATION)
      user_compliance_info_requests.each(&:mark_provided!)
      flash[:notice] = "Thanks! You're all set."
    end

    safe_redirect_to settings_payments_path
  end

  private
    def generate_stripe_verification_url
      Stripe::AccountLink.create({
                                   account: current_seller.stripe_account.charge_processor_merchant_id,
                                   refresh_url: settings_payments_verify_identity_url,
                                   return_url: settings_payments_verify_identity_url,
                                   type: "account_onboarding",
                                 }).url
    end
end

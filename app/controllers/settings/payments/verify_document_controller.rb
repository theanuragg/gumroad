# frozen_string_literal: true

class Settings::Payments::VerifyDocumentController < Sellers::BaseController
  def create
    authorize [:settings, :payments, current_seller], :verify_document?

    if params[:photo_id].nil?
      error = if params[:is_company_id]
        "Please select a company registration document, then submit."
      elsif params[:is_additional_id]
        "Please select a valid document for address verification, then submit."
      elsif params[:is_passport]
        "Please select a passport document, then submit."
      elsif params[:is_visa]
        "Please select a visa document, then submit."
      elsif params[:is_power_of_attorney]
        "Please select a power of attorney document, then submit."
      elsif params[:is_memorandum_of_association]
        "Please select a memorandum of association document, then submit."
      elsif params[:is_bank_statement]
        "Please select a bank statement document, then submit."
      elsif params[:is_proof_of_registration]
        "Please select a proof of registration document, then submit."
      elsif params[:is_company_registration_verification]
        "Please select a company registration verification document, then submit."
      else
        "Please select a government-issued photo ID, then submit."
      end
      return render json: { success: false, error: }
    end

    stripe_account_id = current_seller.stripe_account.charge_processor_merchant_id
    old_compliance_info = current_seller.fetch_or_build_user_compliance_info
    pending_info_requests = current_seller.user_compliance_info_requests.requested

    begin
      is_purpose_account_requirement = (params[:is_company_id] && old_compliance_info.country_code == Compliance::Countries::ARE.alpha2) ||
          params[:is_passport] || params[:is_visa] || params[:is_power_of_attorney] || params[:is_memorandum_of_association] || params[:is_bank_statement] ||
          params[:is_proof_of_registration] || params[:is_company_registration_verification]

      file = Stripe::File.create(
        {
          purpose: is_purpose_account_requirement ? "account_requirement" : "identity_document",
          file: params[:photo_id].tempfile
        },
        { stripe_account: stripe_account_id }
      )
    rescue Stripe::InvalidRequestError
      error = "We weren't able to parse your document. Please upload it as a JPEG or PNG file."
      return render json: { success: false, error: }
    end

    if params[:is_company_id]
      if old_compliance_info.country_code == Compliance::Countries::ARE.alpha2
        Stripe::Account.update(
          stripe_account_id,
          documents: {
            company_license: {
              files: [file.id],
            },
          },
        )
      else
        Stripe::Account.update(
          stripe_account_id,
          company: {
            verification: {
              document: {
                front: file.id,
              },
            },
          },
        )
      end
      # Marking the pending requests as completed below when the corresponding documents are uploaded.
      # If the uploaded document fails verification, a new request will get created and a notification email sent to the creator.
      pending_info_requests.where(field_needed: UserComplianceInfoFields::Business::STRIPE_COMPANY_DOCUMENT_ID).each(&:mark_provided!)
      old_compliance_info.dup_and_save do |new_compliance_info|
        new_compliance_info.stripe_company_document_id = file.id
      end
    elsif params[:is_memorandum_of_association]
      Stripe::Account.update(
        stripe_account_id,
        documents: {
          company_memorandum_of_association: {
            files: [file.id],
          },
        },
      )
      pending_info_requests.where(field_needed: UserComplianceInfoFields::Business::MEMORANDUM_OF_ASSOCIATION).each(&:mark_provided!)
    elsif params[:is_bank_statement]
      Stripe::Account.update(
        stripe_account_id,
        documents: {
          bank_account_ownership_verification: {
            files: [file.id],
          },
        },
      )
      pending_info_requests.where(field_needed: UserComplianceInfoFields::Business::BANK_STATEMENT).each(&:mark_provided!)
    elsif params[:is_proof_of_registration]
      Stripe::Account.update(
        stripe_account_id,
        documents: {
          proof_of_registration: {
            files: [file.id],
          },
        },
        )
      pending_info_requests.where(field_needed: UserComplianceInfoFields::Business::PROOF_OF_REGISTRATION).each(&:mark_provided!)
    elsif params[:is_company_registration_verification]
      Stripe::Account.update(
        stripe_account_id,
        documents: {
          company_registration_verification: {
            files: [file.id],
          },
        },
        )
      pending_info_requests.where(field_needed: UserComplianceInfoFields::Business::COMPANY_REGISTRATION_VERIFICATION).each(&:mark_provided!)
    elsif params[:is_additional_id]
      stripe_person = Stripe::Account.list_persons(stripe_account_id)["data"].last
      Stripe::Account.update_person(
        stripe_account_id,
        stripe_person.id,
        verification: {
          additional_document: {
            front: file.id,
          },
        },
      )
      pending_info_requests.where(field_needed: UserComplianceInfoFields::Individual::STRIPE_ADDITIONAL_DOCUMENT_ID).each(&:mark_provided!)
      old_compliance_info.dup_and_save do |new_compliance_info|
        new_compliance_info.stripe_additional_document_id = file.id
      end
    elsif params[:is_passport]
      stripe_person = Stripe::Account.list_persons(stripe_account_id)["data"].last
      Stripe::Account.update_person(
        stripe_account_id,
        stripe_person.id,
        documents: {
          passport: {
            files: [file.id],
          },
        },
      )
      pending_info_requests.where(field_needed: UserComplianceInfoFields::Individual::PASSPORT).each(&:mark_provided!)
    elsif params[:is_visa]
      stripe_person = Stripe::Account.list_persons(stripe_account_id)["data"].last
      Stripe::Account.update_person(
        stripe_account_id,
        stripe_person.id,
        documents: {
          visa: {
            files: [file.id],
          },
        },
      )
      pending_info_requests.where(field_needed: UserComplianceInfoFields::Individual::VISA).each(&:mark_provided!)
    elsif params[:is_power_of_attorney]
      stripe_person = Stripe::Account.list_persons(stripe_account_id)["data"].last
      Stripe::Account.update_person(
        stripe_account_id,
        stripe_person.id,
        documents: {
          company_authorization: {
            files: [file.id],
          },
        },
      )
      pending_info_requests.where(field_needed: UserComplianceInfoFields::Individual::POWER_OF_ATTORNEY).each(&:mark_provided!)
    else
      stripe_person = Stripe::Account.list_persons(stripe_account_id)["data"].last
      Stripe::Account.update_person(
        stripe_account_id,
        stripe_person.id,
        verification: {
          document: {
            front: file.id,
          },
        },
      )
      pending_info_requests.where(field_needed: UserComplianceInfoFields::Individual::STRIPE_IDENTITY_DOCUMENT_ID).each(&:mark_provided!)
      old_compliance_info.dup_and_save do |new_compliance_info|
        new_compliance_info.stripe_identity_document_id = file.id
      end
    end

    render json: { success: true }
  end
end

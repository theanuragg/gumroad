# frozen_string_literal: true

class Api::Internal::Helper::PurchasesController < Api::Internal::Helper::BaseController
  before_action :authorize_helper_token!
  before_action :fetch_last_purchase, except: [:search, :resend_receipt_by_number, :reassign_purchases]

  REFUND_LAST_PURCHASE_OPENAPI = {
    summary: "Refund last purchase",
    description: "Refund last purchase based on the customer email, should be used when within product refund policy",
    requestBody: {
      required: true,
      content: {
        'application/json': {
          schema: {
            type: "object",
            properties: {
              email: { type: "string", description: "Email address of the customer" }
            },
            required: ["email"]
          }
        }
      }
    },
    security: [{ bearer: [] }],
    responses: {
      '200': {
        description: "Successfully refunded purchase",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { const: true },
                message: { type: "string" }
              }
            }
          }
        }
      },
      '422': {
        description: "Purchase not found or not refundable",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { const: false },
                message: { type: "string" }
              }
            }
          }
        }
      }
    }
  }.freeze
  def refund_last_purchase
    if @purchase.present? && @purchase.refund_and_save!(GUMROAD_ADMIN_ID)
      render json: { success: true, message: "Successfully refunded purchase ID #{@purchase.id}" }
    else
      render json: { success: false, message: @purchase.present? ? @purchase.errors.full_messages.to_sentence : "Purchase not found" }, status: :unprocessable_entity
    end
  end

  RESEND_LAST_RECEIPT_OPENAPI = {
    summary: "Resend receipt",
    description: "Resend last receipt to customer",
    requestBody: {
      required: true,
      content: {
        'application/json': {
          schema: {
            type: "object",
            properties: {
              email: { type: "string", description: "Email address of the customer" }
            },
            required: ["email"]
          }
        }
      }
    },
    security: [{ bearer: [] }],
    responses: {
      '200': {
        description: "Successfully resent receipt",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { const: true },
                message: { type: "string" }
              }
            }
          }
        },
      },
      '422': {
        description: "Purchase not found",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { const: false },
                message: { type: "string" }
              }
            }
          }
        }
      },
    }
  }.freeze
  def resend_last_receipt
    @purchase.resend_receipt
    render json: { success: true, message: "Successfully resent receipt for purchase ID #{@purchase.id}" }
  end

  SEARCH_PURCHASE_OPENAPI = {
    summary: "Search purchase",
    description: "Search purchase by email, seller, license key, or card details. At least one of the parameters is required.",
    requestBody: {
      required: true,
      content: {
        'application/json': {
          schema: {
            type: "object",
            properties: {
              email: { type: "string", description: "Email address of the customer/buyer" },
              creator_email: { type: "string", description: "Email address of the creator/seller" },
              license_key: { type: "string", description: "Product license key (4 groups of alphanumeric characters separated by dashes)" },
              charge_amount: { type: "number", description: "Charge amount in dollars" },
              purchase_date: { type: "string", description: "Purchase date in YYYY-MM-DD format" },
              card_type: { type: "string", description: "Card type" },
              card_last4: { type: "string", description: "Last 4 digits of the card" }
            },
          }
        }
      }
    },
    security: [{ bearer: [] }],
    responses: {
      '200': {
        description: "Purchase found",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { const: true },
                message: { const: "Purchase found" },
                purchase: {
                  type: "object",
                  properties: {
                    id: { type: "integer" },
                    email: { type: "string" },
                    link_name: { type: "string" },
                    price_cents: { type: "integer" },
                    purchase_state: { type: "string" },
                    created_at: { type: "string", format: "date-time" },
                    receipt_url: { type: "string", format: "uri" }
                  }
                }
              }
            }
          }
        }
      },
      '404': {
        description: "Purchase not found",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { const: false },
                message: { const: "Purchase not found" }
              }
            }
          }
        }
      },
      '400': {
        description: "Invalid date format",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { const: false },
                message: { const: "purchase_date must use YYYY-MM-DD format." }
              }
            }
          }
        }
      }
    }
  }.freeze
  def search
    search_params = {
      query: params[:email],
      creator_email: params[:creator_email],
      license_key: params[:license_key],
      transaction_date: params[:purchase_date],
      price: params[:charge_amount].present? ? params[:charge_amount].to_f : nil,
      card_type: params[:card_type],
      last_4: params[:card_last4],
    }
    return render json: { success: false, message: "At least one of the parameters is required." }, status: :bad_request if search_params.compact.blank?

    purchase = AdminSearchService.new.search_purchases(**search_params, limit: 1).first
    return render json: { success: false, message: "Purchase not found" }, status: :not_found if purchase.nil?

    purchase_json = purchase.slice(:email, :link_name, :price_cents, :purchase_state, :created_at)
    purchase_json[:id] = purchase.external_id_numeric
    purchase_json[:receipt_url] = receipt_purchase_url(purchase.external_id, host: UrlService.domain_with_protocol, email: purchase.email)
    render json: { success: true, message: "Purchase found", purchase: purchase_json }
  rescue AdminSearchService::InvalidDateError
    render json: { success: false, message: "purchase_date must use YYYY-MM-DD format." }, status: :bad_request
  end

  RESEND_RECEIPT_BY_NUMBER_OPENAPI = {
    summary: "Resend receipt by purchase number",
    description: "Resend receipt to customer using purchase number",
    requestBody: {
      required: true,
      content: {
        'application/json': {
          schema: {
            type: "object",
            properties: {
              purchase_number: { type: "string", description: "Purchase number/ID" }
            },
            required: ["purchase_number"]
          }
        }
      }
    },
    security: [{ bearer: [] }],
    responses: {
      '200': {
        description: "Successfully resent receipt",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { const: true },
                message: { type: "string" }
              }
            }
          }
        },
      },
      '404': {
        description: "Purchase not found",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { const: false },
                message: { type: "string" }
              }
            }
          }
        }
      },
    }
  }.freeze

  def resend_receipt_by_number
    purchase = Purchase.find_by_external_id_numeric(params[:purchase_number].to_i)
    return e404_json unless purchase.present?

    purchase.resend_receipt
    render json: { success: true, message: "Successfully resent receipt for purchase ID #{purchase.id} to #{purchase.email}" }
  end

  REASSIGN_PURCHASES_OPENAPI = {
    summary: "Reassign purchases",
    description: "Update the email on all purchases belonging to the 'from' email address to the 'to' email address",
    requestBody: {
      required: true,
      content: {
        'application/json': {
          schema: {
            type: "object",
            properties: {
              from: { type: "string", description: "Source email address" },
              to: { type: "string", description: "Target email address" }
            },
            required: ["from", "to"]
          }
        }
      }
    },
    security: [{ bearer: [] }],
    responses: {
      '200': {
        description: "Successfully reassigned purchases",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { const: true },
                message: { type: "string" },
                count: { type: "integer" }
              }
            }
          }
        }
      },
      '400': {
        description: "Missing required parameters",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { const: false },
                message: { type: "string" }
              }
            }
          }
        }
      },
      '404': {
        description: "No purchases found for the given email",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { const: false },
                message: { type: "string" }
              }
            }
          }
        }
      }
    }
  }.freeze

  def reassign_purchases
    from_email = params[:from]
    to_email = params[:to]

    return render json: { success: false, message: "Both 'from' and 'to' email addresses are required" }, status: :bad_request unless from_email.present? && to_email.present?

    purchases = Purchase.where(email: from_email)
    return render json: { success: false, message: "No purchases found for email: #{from_email}" }, status: :not_found if purchases.empty?

    target_user = User.find_by(email: to_email)

    count = 0
    purchases.each do |purchase|
      purchase.email = to_email
      if target_user && purchase.purchaser_id.present?
        purchase.purchaser_id = target_user.id
      else
        purchase.purchaser_id = nil
      end

      if purchase.is_original_subscription_purchase? && purchase.subscription.present?
        if target_user
          purchase.subscription.user = target_user
          purchase.subscription.save
        else
          purchase.subscription.user = nil
          purchase.subscription.save
        end
      end

      count += 1 if purchase.save
    end

    render json: {
      success: true,
      message: "Successfully reassigned #{count} purchases from #{from_email} to #{to_email}",
      count:
    }
  end

  private
    def fetch_last_purchase
      @purchase = Purchase.where(email: params[:email]).order(created_at: :desc).first
      e404_json unless @purchase
    end
end

# frozen_string_literal: true

class Api::Internal::Helper::UsersController < Api::Internal::Helper::BaseController
  before_action :authorize_hmac_signature!, only: :user_info
  before_action :authorize_helper_token!, except: :user_info

  def user_info
    render json: { success: false, error: "'email' parameter is required" }, status: :bad_request if params[:email].blank?

    render json: {
      success: true,
      user_info: HelperUserInfoService.new(email: params[:email]).user_info,
    }
  end

  USER_SUSPENSION_INFO_OPENAPI = {
    summary: "Get user suspension information",
    description: "Retrieve suspension status and details for a user",
    requestBody: {
      required: true,
      content: {
        'application/json': {
          schema: {
            type: "object",
            properties: {
              email: { type: "string", description: "Email address of the user" }
            },
            required: ["email"]
          }
        }
      }
    },
    security: [{ bearer: [] }],
    responses: {
      '200': {
        description: "Successfully retrieved user suspension information",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { type: "boolean" },
                status: { type: "string", description: "Status of the user" },
                updated_at: { type: "string", format: "date-time", nullable: true, description: "When the user's suspension status was last updated" },
                appeal_url: { type: "string", nullable: true, description: "URL for the user to appeal their suspension" }
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
                error: { type: "string" }
              }
            }
          }
        }
      },
      '422': {
        description: "User not found",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { const: false },
                error_message: { type: "string" }
              }
            }
          }
        }
      }
    }
  }.freeze
  def user_suspension_info
    if params[:email].blank?
      render json: { success: false, error: "'email' parameter is required" }, status: :bad_request
      return
    end

    user = User.alive.by_email(params[:email]).first
    if user.blank?
      return render json: { success: false, error_message: "An account does not exist with that email." }, status: :unprocessable_entity
    end

    iffy_url = Rails.env.production? ? "https://api.iffy.com/api/v1/users" : "http://localhost:3000/api/v1/users"

    begin
      response = HTTParty.get(
        "#{iffy_url}?email=#{CGI.escape(params[:email])}",
        headers: {
          "Authorization" => "Bearer #{GlobalConfig.get("IFFY_API_KEY")}"
        }
      )

      if response.success? && response.parsed_response["data"].present? && !response.parsed_response["data"].empty?
        user_data = response.parsed_response["data"].first
        render json: {
          success: true,
          status: user_data["actionStatus"],
          updated_at: user_data["actionStatusCreatedAt"],
          appeal_url: user_data["appealUrl"]
        }
      else
        render json: {
          success: true,
          status: "Compliant",
          suspended_at: nil,
          appeal_url: nil
        }
      end
    rescue HTTParty::Error, Net::OpenTimeout, Net::ReadTimeout, Timeout::Error, Errno::ECONNREFUSED, SocketError => e
      Bugsnag.notify(e)

      render json: {
        success: false,
        error_message: "Failed to retrieve suspension information"
      }, status: :service_unavailable
    end
  end

  SEND_RESET_PASSWORD_INSTRUCTIONS_OPENAPI = {
    summary: "Initiate password reset",
    description: "Send email with instructions to reset password",
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
        description: "Successfully sent reset password instructions",
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
        description: "Email invalid or user not found",
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
  def send_reset_password_instructions
    if params[:email].present? && params[:email].match(User::EMAIL_REGEX)
      user = User.alive.by_email(params[:email]).first
      if user
        user.send_reset_password_instructions
        render json: { success: true, message: "Reset password instructions sent" }
      else
        render json: { error_message: "An account does not exist with that email." },
               status: :unprocessable_entity
      end
    else
      render json: { error_message: "Invalid email" }, status: :unprocessable_entity
    end
  end

  UPDATE_EMAIL_OPENAPI = {
    summary: "Update user email",
    description: "Update a user's email address",
    requestBody: {
      required: true,
      content: {
        'application/json': {
          schema: {
            type: "object",
            properties: {
              current_email: { type: "string", description: "Current email address of the user" },
              new_email: { type: "string", description: "New email address for the user" }
            },
            required: ["current_email", "new_email"]
          }
        }
      }
    },
    security: [{ bearer: [] }],
    responses: {
      '200': {
        description: "Successfully updated email",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                message: { type: "string" }
              }
            }
          }
        }
      },
      '422': {
        description: "Invalid email or user not found",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                error_message: { type: "string" }
              }
            }
          }
        }
      }
    }
  }.freeze
  def update_email
    if params[:current_email].blank? || params[:new_email].blank?
      render json: { error_message: "Both current and new email are required." }, status: :unprocessable_entity
      return
    end

    if !params[:new_email].match(User::EMAIL_REGEX)
      render json: { error_message: "Invalid new email format." }, status: :unprocessable_entity
      return
    end

    user = User.alive.by_email(params[:current_email]).first
    if user
      user.email = params[:new_email]
      if user.save
        render json: { message: "Email updated." }
      else
        render json: { error_message: user.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    else
      render json: { error_message: "An account does not exist with that email." }, status: :unprocessable_entity
    end
  end

  UPDATE_TWO_FACTOR_AUTHENTICATION_ENABLED_OPENAPI = {
    summary: "Update two-factor authentication status",
    description: "Update a user's two-factor authentication enabled status",
    requestBody: {
      required: true,
      content: {
        'application/json': {
          schema: {
            type: "object",
            properties: {
              email: { type: "string", description: "Email address of the user" },
              enabled: { type: "boolean", description: "Whether two-factor authentication should be enabled or disabled" }
            },
            required: ["email", "enabled"]
          }
        }
      }
    },
    security: [{ bearer: [] }],
    responses: {
      '200': {
        description: "Successfully updated two-factor authentication status",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { type: "boolean" },
                message: { type: "string" }
              }
            }
          }
        }
      },
      '422': {
        description: "Invalid email or user not found",
        content: {
          'application/json': {
            schema: {
              type: "object",
              properties: {
                success: { type: "boolean" },
                error_message: { type: "string" }
              }
            }
          }
        }
      }
    }
  }.freeze
  def update_two_factor_authentication_enabled
    if params[:email].blank?
      return render json: { success: false, error_message: "Email is required." }, status: :unprocessable_entity
    end

    if params[:enabled].nil?
      return render json: { success: false, error_message: "Enabled status is required." }, status: :unprocessable_entity
    end

    user = User.alive.by_email(params[:email]).first
    if user.present?
      user.two_factor_authentication_enabled = params[:enabled]
      if user.save
        render json: { success: true, message: "Two-factor authentication #{user.two_factor_authentication_enabled? ? "enabled" : "disabled"}." }
      else
        render json: { success: false, error_message: user.errors.full_messages.join(", ") }, status: :unprocessable_entity
      end
    else
      render json: { success: false, error_message: "An account does not exist with that email." }, status: :unprocessable_entity
    end
  end
end

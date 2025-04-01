# frozen_string_literal: true

class User::PasswordsController < Devise::PasswordsController
  def new
    e404
  end

  def create
    email = params[:user][:email]
    if email.present? && email.match(User::EMAIL_REGEX)
      @user = User.alive.by_email(email).first
      return head :no_content if @user&.send_reset_password_instructions
    end
    render json: { error_message: "An account does not exist with that email." }, status: :unprocessable_entity
  end

  def edit
    @hide_layouts = true
    @body_class = "onboarding-page"

    @reset_password_token = params[:reset_password_token]
    @user = User.find_or_initialize_with_error_by(:reset_password_token,
                                                  Devise.token_generator.digest(User, :reset_password_token, @reset_password_token))
    if @user.errors.present?
      flash[:alert] = "That reset password token doesn't look valid (or may have expired)."
      return redirect_to root_url
    end

    @title = "Reset your password"
  end

  def update
    @hide_layouts = true
    @body_class = "onboarding-page"

    @reset_password_token = params[:user][:reset_password_token]
    @user = User.reset_password_by_token(params[:user])

    if @user.errors.present?
      flash[:alert] = if @user.errors[:password_confirmation].present?
        "Those two passwords didn't match."
      elsif @user.errors[:password].present?
        @user.errors.full_messages.first
      else
        "That reset password token doesn't look valid (or may have expired)."
      end
      render :edit
    else
      flash[:notice] = "Your password has been reset, and you're now logged in."
      @user.invalidate_active_sessions!
      sign_in @user unless @user.deleted?
      redirect_to root_url
    end
  end

  def after_sending_reset_password_instructions_path_for(_resource_name, _user)
    root_url
  end
end

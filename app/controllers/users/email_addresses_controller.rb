class Users::EmailAddressesController < ApplicationController
  before_action :set_user
  before_action :ensure_valid_email_address, only: :create
  rate_limit to: 5, within: 1.hour, only: :create

  def new
  end

  def create
    @user.send_email_address_change_confirmation(new_email_address)

    respond_to do |format|
      format.html
      format.json { head :created }
    end
  end

  private
    def set_user
      @user = Current.identity.users.active.find(params[:user_id])
    end

    def ensure_valid_email_address
      if !new_email_address.match?(URI::MailTo::EMAIL_REGEXP)
        error = t("users_error_invalid_email")
      elsif (identity = Identity.find_by_email_address(new_email_address))
        if identity == @user.identity
          error = t("users_error_already_your_email")
        elsif identity.users.exists?(account: @user.account)
          error = t("users_error_email_used_in_account")
        end
      end

      if error
        respond_to do |format|
          format.html { redirect_to new_user_email_address_path(@user), alert: error }
          format.json { render json: { error: error }, status: :unprocessable_entity }
        end
      end
    end

    def new_email_address
      params.expect :email_address
    end
end

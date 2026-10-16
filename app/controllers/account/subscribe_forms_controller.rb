class Account::SubscribeFormsController < ApplicationController
  wrap_parameters :account, include: %i[ subscription_return_url ]

  before_action :ensure_admin
  before_action :set_account

  def show
  end

  def edit
  end

  def update
    if @account.update(subscribe_form_params)
      respond_to do |format|
        format.html { redirect_to account_settings_path, notice: t("settings_saved") }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @account.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    def set_account
      @account = Current.account
    end

    def subscribe_form_params
      params.expect(account: [ :subscription_return_url ])
    end
end

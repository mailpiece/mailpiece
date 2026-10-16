class Account::HandlesController < ApplicationController
  wrap_parameters :account, include: %i[ handle ]

  before_action :ensure_admin
  before_action :set_account

  def show
  end

  def edit
  end

  # A new address is a new place for every page, so the way back to Settings is built with it.
  def update
    if @account.update(handle_params)
      respond_to do |format|
        format.html { redirect_to account_settings_url(script_name: @account.slug), notice: t("settings_saved") }
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

    def handle_params
      params.expect(account: [ :handle ])
    end
end

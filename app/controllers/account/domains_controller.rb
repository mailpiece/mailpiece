class Account::DomainsController < ApplicationController
  wrap_parameters :account, include: %i[ domain ]

  before_action :ensure_admin
  before_action :set_account

  def show
  end

  def edit
  end

  def update
    if @account.update(domain_params)
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

    def domain_params
      params.expect(account: [ :domain ])
    end
end

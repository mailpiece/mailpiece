class Account::NewslettersController < ApplicationController
  wrap_parameters :account, include: %i[ name description welcome_message avatar locale ]

  before_action :ensure_admin
  before_action :set_account

  def show
  end

  def edit
  end

  def update
    if @account.update(newsletter_params)
      respond_to do |format|
        format.html { redirect_to account_settings_path, notice: @account.in_locale { t("settings_saved") } }
        format.json { render :show }
      end
    else
      @account.drop_unsaved_avatar

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

    def newsletter_params
      params.expect(account: [ :name, :description, :welcome_message, :avatar, :locale ])
    end
end

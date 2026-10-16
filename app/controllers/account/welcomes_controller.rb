class Account::WelcomesController < ApplicationController
  before_action :ensure_admin
  before_action :set_account

  def show
  end

  def create
    @account.start_welcoming

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to account_welcome_path, notice: t("saved") }
      format.json { render :show, status: :created }
    end
  end

  def destroy
    @account.stop_welcoming
    @account.reload

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to account_welcome_path, notice: t("saved") }
      format.json { head :no_content }
    end
  end

  private
    def set_account
      @account = Current.account
    end
end

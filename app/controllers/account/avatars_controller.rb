class Account::AvatarsController < ApplicationController
  allow_unauthenticated_access only: :show

  before_action :ensure_admin, only: :destroy
  before_action :set_account

  def show
    if @account.avatar.attached?
      redirect_to rails_blob_path(@account.avatar_thumbnail, disposition: "inline")
    else
      head :not_found
    end
  end

  def destroy
    @account.avatar.destroy

    respond_to do |format|
      format.html { redirect_to edit_account_newsletter_path }
      format.json { head :no_content }
    end
  end

  private
    def set_account
      @account = Current.account
    end
end

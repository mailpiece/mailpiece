class Account::SendersController < ApplicationController
  wrap_parameters :account_sender, include: %i[ from_name from_address reply_to_address ]

  before_action :ensure_admin
  before_action :set_sender

  def show
  end

  def edit
  end

  def update
    if @sender.update(sender_params)
      respond_to do |format|
        format.html { redirect_to account_settings_path, notice: t("settings_saved") }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @sender.errors, status: :unprocessable_entity }
      end
    end
  end

  private
    def set_sender
      @sender = Current.account.sender || Current.account.build_sender
    end

    def sender_params
      params.expect(account_sender: [ :from_name, :from_address, :reply_to_address ])
    end
end

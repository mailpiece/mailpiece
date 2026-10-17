class Account::Senders::SmtpServersController < ApplicationController
  wrap_parameters :account_sender, include: %i[ smtp_address smtp_port smtp_username smtp_password ]

  before_action :ensure_admin
  before_action :set_sender

  def edit
    redirect_to account_outgoing_mail_path if @sender.smtp?
  end

  def update
    if @sender.use_smtp_server(smtp_server_params)
      respond_to do |format|
        format.html { redirect_to account_outgoing_mail_path, notice: t("settings_saved") }
        format.json { render "account/senders/show" }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @sender.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @sender.stop_sending

    respond_to do |format|
      format.html { redirect_to account_outgoing_mail_path, notice: t("settings_saved") }
      format.json { head :no_content }
    end
  end

  private
    def set_sender
      @sender = Current.account.sender || Current.account.build_sender
    end

    def smtp_server_params
      params.expect(account_sender: %i[ smtp_address smtp_port smtp_username smtp_password ])
    end
end

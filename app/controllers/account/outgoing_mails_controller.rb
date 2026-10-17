class Account::OutgoingMailsController < ApplicationController
  before_action :ensure_admin
  before_action :set_sender

  def show
  end

  private
    def set_sender
      @sender = Current.account.sender || Current.account.build_sender
    end
end

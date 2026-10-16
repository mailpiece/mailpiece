class Subscribers::AddressBouncesController < ApplicationController
  before_action :ensure_admin
  before_action :set_subscriber

  def create
    @subscriber.bounce
    head :no_content
  end

  private
    def set_subscriber
      @subscriber = Current.account.subscribers.find_by!(email: params.expect(:email_address))
    end
end

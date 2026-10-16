class Public::Subscriptions::ConfirmationsController < Public::BaseController
  before_action :no_store
  before_action :set_subscriber

  def show
  end

  def create
    if @subscriber.confirm_using_token(token)
      render :show
    else
      render :invalid_token, status: :unprocessable_entity
    end
  end

  private
    def set_subscriber
      unless @subscriber = Current.account.subscribers.find_by_confirmation_token(token)
        render :invalid_token, status: :unprocessable_entity
      end
    end

    def token
      params.expect :subscription_token
    end
end

module SubscriptionScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_subscriber
  end

  private
    def set_subscriber
      @subscriber = Current.account.subscribers.find_by!(token: params[:subscription_token])
    end
end

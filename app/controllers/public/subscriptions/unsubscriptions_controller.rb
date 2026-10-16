class Public::Subscriptions::UnsubscriptionsController < Public::BaseController
  include SubscriptionScoped

  # Mail providers post here on their own, with no page behind the request (RFC 8058).
  skip_forgery_protection only: :create

  def show
    no_store
  end

  def create
    @subscriber.unsubscribe
    no_store

    render :show
  end
end

class Public::EmbeddedSubscriptionsController < Public::BaseController
  include SubscriptionRequesting

  # Posted by a form on another website, with no page of ours behind the request.
  skip_forgery_protection only: :create

  def create
    subscribe referrer: Current.referrer

    if Current.account.sends_mail? && Current.account.subscription_return_url.present?
      redirect_to Current.account.subscription_return_url, allow_other_host: true
    else
      redirect_to public_subscription_path
    end
  end
end

module SubscriptionRequesting
  extend ActiveSupport::Concern

  included do
    rate_limit to: 10, within: 3.minutes, only: :create, with: -> { head :too_many_requests }
  end

  private
    # A person never sees or fills the "reference" field, and takes a few seconds over the rest: an address
    # that arrives with that field filled, or too soon after its form was drawn, is dropped.
    def subscribe(**source)
      if params[:reference].blank? && !form_stamp.hasty?
        Current.account.subscribers.subscribe(params[:email].to_s, **source)
      end
    end

    def form_stamp
      Subscriber::FormStamp.new(params[:drawn_at])
    end
end

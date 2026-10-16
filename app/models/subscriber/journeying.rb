module Subscriber::Journeying
  extend ActiveSupport::Concern

  included do
    has_many :journey_deliveries, class_name: "Journey::Delivery", dependent: :delete_all
    has_many :journey_runs, class_name: "Journey::Run", dependent: :delete_all
  end

  private
    # Called inside the transaction of what set it off, so the run commits with it.
    def start_journey(trigger)
      account.journey_triggered_by(trigger).start_for(self)
    end
end

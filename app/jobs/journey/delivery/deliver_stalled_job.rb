class Journey::Delivery::DeliverStalledJob < ApplicationJob
  def perform
    Journey::Delivery.deliver_stalled_now
  end
end

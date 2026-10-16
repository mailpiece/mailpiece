class Post::Delivery::DeliverStalledJob < ApplicationJob
  def perform
    Post::Delivery.deliver_stalled_now
  end
end

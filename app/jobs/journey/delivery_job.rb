class Journey::DeliveryJob < ApplicationJob
  include MailDeliveryErrorHandling

  queue_as :mailers

  discard_on ActiveJob::DeserializationError

  def perform(delivery)
    delivery.deliver_now
  end
end

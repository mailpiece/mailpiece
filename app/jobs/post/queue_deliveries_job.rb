class Post::QueueDeliveriesJob < ApplicationJob
  discard_on ActiveJob::DeserializationError
  retry_on ActiveRecord::StatementTimeout, ActiveRecord::Deadlocked, ActiveRecord::ConnectionNotEstablished,
    wait: :polynomially_longer, attempts: 5

  def perform(post)
    post.queue_deliveries_now
  end
end

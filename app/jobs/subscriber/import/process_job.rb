class Subscriber::Import::ProcessJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  def perform(import)
    import.process
  end
end

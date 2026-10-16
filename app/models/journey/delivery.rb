class Journey::Delivery < ApplicationRecord
  include SentOnce

  belongs_to :account, default: -> { email.account }
  belongs_to :email, class_name: "Journey::Email"
  belongs_to :subscriber

  class << self
    private
      # A journey's rows are dated days ahead, so the sweep takes its turns from now and never from behind the last of them.
      def next_slot
        Time.current
      end
  end

  def run
    email.journey.runs.find_by!(subscriber: subscriber)
  end

  # Dropped unsent. An email switched off or deleted is passed over and the run goes on to the next; a person
  # the journey no longer reaches ends it. Only the call that deleted the row moves the run.
  def skip
    transaction do
      if self.class.pending.where(id: id).delete_all == 1
        if reaches_subscriber?
          run.advance(past: email)
        else
          run.end_as :left
        end
      end
    end
  end

  private
    def delivery_job
      Journey::DeliveryJob
    end

    def receivable?
      email.active? && reaches_subscriber?
    end

    # The unsubscribe journey is the one that reaches a person who is not active: its row is theirs
    # only while they are still unsubscribed.
    def reaches_subscriber?
      email.journey.recipients.exists?(subscriber_id)
    end

    def mail
      JourneyMailer.email(email, subscriber, delivery: self)
    end

    def was_sent
      run.advance(past: email)
    end

    def drop
      skip
    end

    # A row that was no longer waiting is not refused, and ends nothing.
    def refuse
      transaction do
        run.end_as :refused if super
      end
    end
end

class Journey::Run < ApplicationRecord
  belongs_to :account, default: -> { subscriber.account }
  belongs_to :subscriber

  enum :state, %w[ in_progress finished left refused ].index_by(&:itself), default: :in_progress

  def journey
    account.journey_triggered_by(trigger)
  end

  # Called from the transaction that stamps or drops the row of the email before. Two workers may get here for
  # the same row, and the run may have ended since, so it is read again under a lock.
  def advance(past: nil)
    with_lock do
      if in_progress?
        if email = journey.next_email_for(subscriber, after: past)
          email.deliver_to(subscriber, at: send_time_of(email))
        else
          end_as :finished
        end
      end
    end
  end

  def end_as(state)
    update!(state: state, ended_at: Time.current) if in_progress?
  end

  private
    # An email switched on late, or one whose turn comes after its day, goes now.
    def send_time_of(email)
      [ email.send_time(entered_at: created_at), Time.current ].max
    end
end

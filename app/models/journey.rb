# The emails a newsletter sends by itself when something happens to a subscriber, in their order. Nothing is stored
# for it: there is one per trigger for every account, and an email says which it belongs to.
class Journey
  TRIGGERS = %w[ subscriber_confirmed subscriber_unsubscribed ].freeze

  attr_reader :account, :trigger

  def self.table_name_prefix
    "journey_"
  end

  def initialize(account, trigger)
    @account, @trigger = account, trigger
  end

  def to_param
    trigger
  end

  def label
    I18n.t("journeys_trigger_#{trigger}")
  end

  def emails
    account.journey_emails.where(trigger: trigger).chronologically
  end

  # The one mail a person who left is sent, so it stays one email that goes at once.
  def to_unsubscribed?
    trigger == "subscriber_unsubscribed"
  end

  def single?
    to_unsubscribed?
  end

  def addable?
    !single? || emails.none?
  end

  def delayed?
    !single?
  end

  def recipients
    if to_unsubscribed?
      account.subscribers.unsubscribed
    else
      account.subscribers.active
    end
  end

  def runs
    account.journey_runs.where(trigger: trigger)
  end

  # A person enters a journey once, ever, and only its first email is given a row: the next is written when
  # that one is sent. With nothing to send no run is written, so a journey written later still takes them.
  def start_for(subscriber)
    if next_email_for(subscriber) && account.sends_mail?
      runs.create_or_find_by!(subscriber: subscriber).tap do |run|
        run.advance if run.previously_new_record?
      end
    end
  end

  # The first email switched on that the person has no row for and that comes after the one given, in the order
  # the emails are in today: a run never goes back.
  def next_email_for(subscriber, after: nil)
    if after.nil? || !single?
      (emails_after(after) & emails.active.not_given_to(subscriber)).first
    end
  end

  private
    def emails_after(email)
      if email
        emails.drop_while { |other| other != email }.drop(1)
      else
        emails.to_a
      end
    end
end

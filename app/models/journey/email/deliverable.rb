module Journey::Email::Deliverable
  extend ActiveSupport::Concern

  included do
    # Before the rows go, so a run waiting on this email moves on to the next.
    before_destroy :skip_waiting_deliveries, unless: :destroyed_by_association

    has_many :deliveries, class_name: "Journey::Delivery", dependent: :delete_all

    scope :not_given_to, ->(subscriber) { where.not(id: subscriber.journey_deliveries.select(:email_id)) }
  end

  def deliverable?
    account.sends_mail?
  end

  def testable?
    deliverable?
  end

  # A person gets an email once, ever: the unique index refuses a second row, and only the call that wrote
  # the row queues it. One left without its job is finished by the sweep. A missing sender writes the row
  # all the same, which waits for it as any row does: a run with no row waiting would never move again.
  def deliver_to(subscriber, at:)
    if active?
      deliveries.create_or_find_by!(subscriber: subscriber).tap do |delivery|
        delivery.deliver_later(at: at) if delivery.previously_new_record?
      end
    end
  end

  def deliver_test_to(email_address)
    if !email_address.match?(URI::MailTo::EMAIL_REGEXP)
      errors.add :base, I18n.t("posts_invalid_test_address")
      nil
    elsif !written?
      errors.add :base, I18n.t("journeys_test_not_written")
      nil
    elsif sender_complete?
      JourneyMailer.test_email(self, email_address).deliver_later
    end
  end

  private
    def skip_waiting_deliveries
      deliveries.pending.find_each(&:skip)
    end

    # Says why on the record, so a screen answers with the refusal.
    def sender_complete?
      if deliverable?
        true
      else
        errors.add :sender, I18n.t("posts_unsent_sender")
        false
      end
    end
end

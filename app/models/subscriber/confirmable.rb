module Subscriber::Confirmable
  extend ActiveSupport::Concern

  CONFIRMATIONS_LIMIT = 1
  CONFIRMATIONS_PER_HOUR = 100
  CONFIRMATION_TOKEN_PURPOSE = "confirm_subscription"
  CONFIRMATION_TOKEN_EXPIRATION = 7.days

  included do
    scope :confirmation_due, -> do
      where(deactivated_at: nil, confirmations_count: ...CONFIRMATIONS_LIMIT)
        .and(where(confirmed_at: nil).or(where.not(unsubscribed_at: nil)).or(where.not(bounced_at: nil)))
    end
  end

  class_methods do
    # A newsletter mails so many confirmations an hour and no more, so a flood of strangers' addresses
    # cannot spend its sender's name. An address over that is dropped with no row, and may ask again.
    # Where the person came from is kept only on the row this makes, never written over by a later request.
    def subscribe(email, source_post: nil, referrer: nil)
      if scoped_account.sends_mail? && !flooded? && !Subscriber::SuspiciousAddress.new(email).suspicious?
        create_or_find_by(email: email) { |subscriber| subscriber.assign_attributes(source_post: source_post, referrer: referrer) }.tap do |subscriber|
          subscriber.request_confirmation if subscriber.persisted?
        end
      else
        new(email: email)
      end
    end

    # Called on an account's own subscribers, so a link for another account's row finds nothing.
    def find_by_confirmation_token(token)
      if parsed_token = SignedGlobalID.parse(token, for: CONFIRMATION_TOKEN_PURPOSE)
        find_by(id: parsed_token.model_id).then do |subscriber|
          subscriber if subscriber&.confirmable_using_token?(token)
        end
      end
    end

    # A row that stays off the list says so with one error, which names what kept it off.
    def add(email)
      create_or_find_by(email: email) { |subscriber| subscriber.confirmed_at = Time.current }.tap do |subscriber|
        subscriber.confirm if subscriber.persisted? && subscriber.unconfirmed?

        unless subscriber.listed?
          subscriber.errors.clear
          subscriber.errors.add :email, I18n.t(subscriber.persisted? ? "subscribers_batch_refusal_#{subscriber.status}" : "subscribers_not_address")
        end
      end
    end

    private
      # Both are called on an account's own subscribers, so a new row names the account.
      def scoped_account
        new.account || raise(ArgumentError, "subscribe is called on an account's subscribers")
      end

      def flooded?
        where(confirmation_sent_at: 1.hour.ago..).count >= CONFIRMATIONS_PER_HOUR
      end
  end

  # With no link in hand only a row that never confirmed is confirmed: this is how an admin adds it.
  def confirm
    record_confirmation if unconfirmed?
  end

  # An unsubscribed or bounced row comes back only through a confirmation mailed after it left, which
  # proves the mailbox takes mail again. The link stands for the row as it was when it was mailed, so
  # it dies when it is used, when the row leaves or is stopped, and when a newer one is mailed.
  # A stopped row stays the admin's.
  def confirmable_using_token?(token)
    parsed_token = SignedGlobalID.parse(token, for: CONFIRMATION_TOKEN_PURPOSE)

    if parsed_token.nil? || parsed_token.model_name != self.class.name || parsed_token.model_id != id.to_s
      false
    else
      !deactivated_at? && parsed_token.params&.dig("state") == confirmation_state
    end
  end

  # The person's link or an admin confirming one unconfirmed row starts the journey, never a row added or imported.
  def confirm_using_token(token)
    if confirmable_using_token?(token)
      record_confirmation_and_start_journey
      notify_admins_later

      true
    else
      false
    end
  end

  # Only an unconfirmed row: the person alone undoes an unsubscribe or a bounce.
  def confirm_and_welcome
    record_confirmation_and_start_journey if unconfirmed?
  end

  def request_confirmation
    deliver_confirmation_later if account.sends_mail? && claim_confirmation
  end

  private
    def record_confirmation_and_start_journey
      transaction do
        record_confirmation
        start_journey "subscriber_confirmed"
      end
    end

    def record_confirmation
      update!(confirmed_at: Time.current, unsubscribed_at: nil, bounced_at: nil, confirmations_count: 0)
    end

    def notify_admins_later
      account.users.admin.where.not(verified_at: nil).joins(:settings).merge(User::Settings.where(new_subscriber_notifications: true)).each do |user|
        NotificationMailer.new_subscriber(user, self).deliver_later
      end
    end

    # One conditional UPDATE, so of several requests at once only one sends the mail.
    def claim_confirmation
      self.class.confirmation_due.where(id: id).update_counters(confirmations_count: 1, touch: :confirmation_sent_at) == 1
    end

    # The claim wrote to the row behind this object's back, so it is read again before the link is made.
    def deliver_confirmation_later
      reload
      SubscriberMailer.confirmation(self, token: generate_confirmation_token).deliver_later
    end

    def generate_confirmation_token(**options)
      options = options.with_defaults(
        for: CONFIRMATION_TOKEN_PURPOSE,
        expires_in: CONFIRMATION_TOKEN_EXPIRATION,
        state: confirmation_state,
      )

      to_sgid(**options).to_s
    end

    def confirmation_state
      dates = [ confirmation_sent_at, confirmed_at, unsubscribed_at, bounced_at, deactivated_at ]

      Digest::SHA256.hexdigest dates.map { |date| date&.utc&.iso8601(6) }.join("/")
    end
end

module SentOnce
  extend ActiveSupport::Concern

  STALLED_AFTER = 2.hours
  UNSCHEDULED_AFTER = 15.minutes
  UNAUTHORIZED_REPORT_INTERVAL = 1.hour
  UNVERIFIED_AFTER = 5.minutes

  included do
    scope :sent, -> { where.not(sent_at: nil) }
    scope :refused, -> { where.not(refused_at: nil) }
    scope :pending, -> { where(sent_at: nil, refused_at: nil, claimed_at: nil) }
    scope :unverified, -> { where(sent_at: nil, refused_at: nil, claimed_at: ..UNVERIFIED_AFTER.ago) }
    scope :unscheduled, -> { pending.where(deliver_at: nil) }
    scope :stalled, -> do
      pending.where(account_id: Account.active.select(:id))
        .and(where(deliver_at: ...STALLED_AFTER.ago).or(where(deliver_at: nil, created_at: ...UNSCHEDULED_AFTER.ago)))
    end
  end

  class_methods do
    # One message every interval, queued behind whatever any newsletter already has
    # waiting, keeps the whole app under the sender's submission limit.
    def deliver_later
      first_slot = next_slot

      pending.find_each.with_index do |delivery, position|
        delivery.deliver_later(at: first_slot + position * interval)
      rescue => error
        Rails.error.report(error, handled: true, context: { delivery_id: delivery.id })
      end
    end

    def deliver_stalled_later
      self::DeliverStalledJob.perform_later
    end

    def deliver_stalled_now
      stalled.deliver_later
    end

    private
      def next_slot
        [ unscoped.pending.maximum(:deliver_at)&.advance(seconds: interval), Time.current ].compact.max
      end

      def interval
        60.0 / Integer(ENV.fetch("MAIL_DELIVERIES_PER_MINUTE", 20))
      end
  end

  def deliver_later(at: Time.current)
    update!(deliver_at: at)
    delivery_job.set(wait_until: at).perform_later(self)
  end

  def deliver_now
    if pending? && account.active? && account.sends_mail?
      if receivable?
        send_mail
      else
        drop
      end
    end
  rescue MailDelivery::Unauthorized => error
    report_unauthorized(error)
    raise
  rescue MailDelivery::Refused
    refuse
    raise
  end

  def pending?
    sent_at.nil? && refused_at.nil? && claimed_at.nil?
  end

  # Claimed for a send whose end was never recorded: the message may have gone or not, so it is
  # never sent again. A claim this young is still a send under way.
  def unverified?
    sent_at.nil? && refused_at.nil? && claimed_at? && claimed_at <= UNVERIFIED_AFTER.ago
  end

  def state
    if sent_at?
      "sent"
    elsif refused_at?
      "refused"
    elsif unverified?
      "unverified"
    else
      "pending"
    end
  end

  private
    # Asked again at the last moment: the subscriber may have left since the row was written.
    def receivable?
      account.subscribers.active.exists?(subscriber_id)
    end

    # The message is built before the row is claimed, so one that cannot be rendered claims nothing.
    def send_mail
      message = mail.tap(&:message)

      if claim
        message.deliver_now
        record_sent(message)
      end
    rescue MailDelivery::Unverified => error
      if claimed_at?
        Rails.error.report(error, handled: true, severity: :warning, context: { delivery_id: id })
      else
        raise
      end
    rescue MailDelivery::Error
      release
      raise
    end

    # The relay sends a message once by its key however often it is posted, so it needs no claim. Over
    # SMTP the row is taken in one UPDATE before the mail goes, so of two workers only one sends, and a
    # claim nobody released or stamped stands for good: the sweep and a retry both pass it by.
    def claim
      if MailTransport.newsletter(account).idempotent?
        true
      elsif self.class.pending.where(id: id).update_all(claimed_at: Time.current) == 1
        reload
      end
    end

    # Opened once the mail has gone, so no transaction waits on the server: the stamp and what follows it commit
    # together. Two workers may both get here on a transport that needs no claim, and only the first sets anything off.
    def record_sent(message)
      with_lock do
        newly_sent = sent_at.nil?
        update!(sent_at: Time.current, message_id: message.message_id)
        was_sent if newly_sent
      end
    end

    # What a row's sending sets off, for a row that sets anything off.
    def was_sent
    end

    def release
      update!(claimed_at: nil) if claimed_at?
    end

    def drop
      destroy
    end

    # Every row of a list fails the same way, so the account is reported once an interval, not once a row.
    def report_unauthorized(error)
      if Rails.cache.write("#{self.class.table_name}/unauthorized/#{account_id}", true, unless_exist: true, expires_in: UNAUTHORIZED_REPORT_INTERVAL)
        Rails.error.report(error, handled: true, severity: :error, context: { account_id: account.external_account_id, account_name: account.name })
      end
    end

    def refuse
      update!(refused_at: Time.current) if pending?
    end
end

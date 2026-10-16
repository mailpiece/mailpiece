module Post::Deliverable
  extend ActiveSupport::Concern

  DELIVERY_BATCH_SIZE = 1000
  NO_DELIVERY_PROGRESS = { sent: 0, refused: 0, unverified: 0 }.freeze

  included do
    has_many :deliveries, class_name: "Post::Delivery", dependent: :delete_all

    scope :sent, -> { where.not(sent_at: nil) }

    attr_writer :delivery_progress
  end

  class_methods do
    def delivery_progress
      unverified = Post::Delivery.unverified.where(post_id: select(:id)).group(:post_id).count

      joins(:deliveries).group(:id)
        .pluck(:id, "COUNT(post_deliveries.sent_at)", "COUNT(post_deliveries.refused_at)")
        .to_h { |id, sent, refused| [ id, { sent: sent, refused: refused, unverified: unverified.fetch(id, 0) } ] }
    end

    # A list counts all its posts in one query; a post loaded any other way counts its own when asked.
    def with_delivery_progress
      progress = unscope(:includes, :order).delivery_progress

      all.tap do |posts|
        posts.each { |post| post.delivery_progress = progress.fetch(post.id, NO_DELIVERY_PROGRESS) }
      end
    end

    # A page is cut from its list after with_delivery_progress would count it, so a page's posts are counted once loaded.
    def load_delivery_progress(posts)
      progress = where(id: posts.map(&:id)).delivery_progress

      posts.each { |post| post.delivery_progress = progress.fetch(post.id, NO_DELIVERY_PROGRESS) }
    end
  end

  def deliverable?
    account.sends_mail?
  end

  # The editor offers a test on a draft only, though a post already published can still be mailed.
  def testable?
    draft? && deliverable?
  end

  def sent?
    sent_at.present?
  end

  def sending?
    sent? && (deliveries_count.zero? || delivery_progress.values.sum < deliveries_count)
  end

  def delivery_progress
    @delivery_progress ||= self.class.where(id: id).delivery_progress.fetch(id, NO_DELIVERY_PROGRESS)
  end

  # A post goes to the list once, and the list is whoever is active in this transaction:
  # the rows commit with sent_at, so a send can lose its job and still be finished by the sweep.
  def deliver
    with_lock do
      if sender_complete? && !sent?
        publish
        create_deliveries

        if deliveries.exists?
          record_links
          update_columns(sent_at: Time.current, deliveries_count: deliveries.count, touch: true)
          queue_deliveries_later
        end
      end
    end
  end

  def queue_deliveries_later
    Post::QueueDeliveriesJob.perform_later(self)
  end

  def queue_deliveries_now
    if sent? && deliverable?
      fetch_video_thumbnails_before_sending
      deliveries.unscheduled.deliver_later
    end
  end

  def deliver_test_to(email_address)
    if !email_address.match?(URI::MailTo::EMAIL_REGEXP)
      errors.add :base, I18n.t("posts_invalid_test_address")
      nil
    elsif sender_complete?
      PostMailer.test_issue(self, email_address).deliver_later
    end
  end

  private
    # Says why on the record, so a screen and the JSON answer with the same refusal.
    def sender_complete?
      if deliverable?
        true
      else
        errors.add :sender, I18n.t("posts_unsent_sender")
        false
      end
    end

    # An issue waits on no picture: whatever goes wrong fetching one, it goes out with YouTube's.
    def fetch_video_thumbnails_before_sending
      fetch_video_thumbnails_now
    rescue => error
      Rails.error.report(error, handled: true, severity: :warning)
    end

    def create_deliveries
      account.subscribers.active.in_batches(of: DELIVERY_BATCH_SIZE) do |subscribers|
        deliveries.insert_all subscribers.pluck(:id).map { |subscriber_id| delivery_row_for(subscriber_id) }
      end
    end

    def delivery_row_for(subscriber_id)
      { id: ActiveRecord::Type::Uuid.generate, account_id: account_id, subscriber_id: subscriber_id }
    end
end

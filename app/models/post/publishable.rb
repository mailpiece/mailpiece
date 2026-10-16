module Post::Publishable
  extend ActiveSupport::Concern

  VISIBILITIES = %w[ listed unlisted email_only ].freeze

  included do
    enum :visibility, VISIBILITIES.index_by(&:itself), default: :listed, validate: true

    scope :published, -> { where.not(published_at: nil) }
    scope :on_the_web, -> { where(visibility: %w[ listed unlisted ]) }
    scope :drafts, -> { where(published_at: nil) }
    scope :recently_published_first, -> { order(published_at: :desc, id: :desc) }

    validate :published_at_is_kept_and_not_ahead, if: :published_at_changed?
  end

  def published?
    published_at.present?
  end

  def draft?
    !published?
  end

  def on_the_web?
    !email_only?
  end

  # An email-only post's date is the moment it went out, so only a post with a page has a date to correct.
  def redatable?
    published? && on_the_web?
  end

  # The editor's fields hold a day and a whole hour, so a date sent back as it was shown changes nothing.
  def published_at=(time)
    time = self.class.type_for_attribute(:published_at).cast(time)

    if published_at_was && time == published_at_was.beginning_of_hour
      super(published_at_was)
    else
      super(time)
    end
  end

  # Either may arrive first. A day left blank empties the date, which the post refuses.
  def published_day=(day)
    @published_day = day
    self.published_at = self.class.on_the_hour(@published_day, @published_hour)
  end

  def published_hour=(hour)
    @published_hour = hour
    self.published_at = self.class.on_the_hour(@published_day, @published_hour) unless @published_day.nil?
  end

  # For an email-only post this is the moment it went out: it is never given a page.
  def publish(at: Time.current)
    with_lock do
      update!(published_at: at, scheduled_posting_at: nil, scheduled_delivery: false) if draft?
    end
  end

  # An old issue takes its place in the archive under its real date, and is never mailed for it: it stays unsent.
  # The time is read as a schedule's is.
  def backdate(at:, visibility: self.visibility)
    at = self.class.type_for_attribute(:published_at).cast(at)

    with_lock do
      if draft? && backdatable?(at: at, visibility: visibility)
        update! visibility: visibility
        publish at: at
      end
    end
  end

  # Takes the page down. An issue already mailed stays what went out, by email only; a post never mailed is a
  # draft again, past the validation that keeps an editor from emptying its date.
  def unpublish
    with_lock do
      if published? && on_the_web?
        if sent?
          update! visibility: :email_only
        else
          update_columns published_at: nil, dated_at: scheduled_posting_at, touch: true
        end
      end
    end
  end

  def list
    update! visibility: :listed if published? && on_the_web?
  end

  def unlist
    update! visibility: :unlisted if published? && on_the_web?
  end

  # A page for an issue that went out by email only, or that lost its page since.
  def publish_on_the_web
    with_lock do
      update! visibility: :listed if sent? && email_only?
    end
  end

  private
    # Only unpublish empties the date, and a date still to come is a schedule's. An emptied date is put back,
    # so the post refused is still shown as the published one it is.
    def published_at_is_kept_and_not_ahead
      if published_at.nil?
        restore_published_at!
        errors.add :base, I18n.t("posts_published_at_blank")
      elsif published_at.future?
        errors.add :base, I18n.t("posts_published_at_future")
      end
    end

    # Says why on the record, as a schedule does, and forgets what an earlier try said.
    def backdatable?(at:, visibility:)
      errors.clear
      errors.add :base, I18n.t("posts_backdate_needs_past") unless at&.past?
      errors.add :base, I18n.t("posts_backdate_not_mailed") if visibility.to_s == "email_only"

      errors.none?
    end
end

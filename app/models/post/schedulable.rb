module Post::Schedulable
  extend ActiveSupport::Concern

  included do
    scope :scheduled, -> { drafts.where.not(scheduled_posting_at: nil) }
    scope :unscheduled, -> { where(scheduled_posting_at: nil) }
    scope :latest_first, -> { order(scheduled_posting_at: :desc, id: :desc) }
    scope :due, -> { scheduled.where(scheduled_posting_at: ..Time.current).joins(:account).merge(Account.active) }
  end

  class_methods do
    def publish_due_later
      Post::PublishDueJob.perform_later
    end

    def publish_due_now
      due.find_each do |post|
        Rails.error.handle { post.publish_as_scheduled }
      end
    end
  end

  def scheduled?
    draft? && scheduled_posting_at.present?
  end

  # The time arrives as the form or the JSON wrote it, so it is read the way the column reads it before it is judged.
  def schedule(at:, deliver: false, visibility: self.visibility)
    at = self.class.type_for_attribute(:scheduled_posting_at).cast(at)

    if draft? && schedulable?(at: at, deliver: deliver, visibility: visibility)
      update scheduled_posting_at: at, scheduled_delivery: deliver, visibility: visibility
    end
  end

  def unschedule
    with_lock do
      update! scheduled_posting_at: nil, scheduled_delivery: false
    end
  end

  # Two runs may find the same post, and the writer may have moved or cancelled the time since it was found.
  def publish_as_scheduled
    with_lock do
      if scheduled? && scheduled_posting_at.past?
        if scheduled_delivery? && deliverable?
          deliver
        else
          publish
        end
      end
    end
  end

  private
    # Says why on the record, so a screen and the JSON answer with the same refusal, and forgets what an earlier try said.
    def schedulable?(at:, deliver:, visibility:)
      errors.clear
      errors.add :base, I18n.t("posts_past_schedule") unless at&.future?
      errors.add :base, I18n.t("posts_email_only_needs_sending") if visibility == "email_only" && !deliver

      errors.none?
    end
end

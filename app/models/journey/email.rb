class Journey::Email < ApplicationRecord
  include Deliverable, Schedulable
  include Post::Readable

  belongs_to :account, default: -> { Current.account }

  has_rich_text :body

  normalizes :subject, with: ->(subject) { subject.squish }
  normalizes :summary, with: ->(summary) { summary.squish.truncate(Post::SUMMARY_LENGTH, separator: /\s/).presence }

  validates :subject, :body, presence: true, if: :active?

  scope :active, -> { where(active: true) }

  def journey
    account.journey_triggered_by(trigger)
  end

  def draft?
    !active?
  end

  def activate
    if active?
      true
    elsif activatable?
      update!(active: true)
    else
      false
    end
  end

  def deactivate
    update! active: false
  end

  # Only a draft's editor says it is one, so one left open on an email switched on since changes nothing.
  def edit_from_editor(attributes, of_draft:)
    if of_draft
      with_lock { update(attributes) if draft? }
    else
      update(attributes)
    end
  end

  def written?
    subject.present? && body.present?
  end

  # The issue's renderer asks these of what it draws: an email of a journey has no page, records no links and
  # keeps no copy of a video's thumbnail.
  def on_the_web?
    false
  end

  def links
    Post::Link.none
  end

  def video_thumbnail(video)
    nil
  end

  # A mail client loads an email's images with no session.
  def publicly_accessible?
    true
  end

  private
    # Says why on the record, so the screen answers with the refusal, and forgets what an earlier try said.
    def activatable?
      errors.clear
      errors.add :subject, :blank if subject.blank?
      errors.add :body, :blank if body.blank?

      errors.none?
    end
end

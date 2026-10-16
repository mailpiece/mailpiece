module Post::Editable
  extend ActiveSupport::Concern

  MINIMUM_TIME_BETWEEN_VERSIONS = 10.minutes

  included do
    has_many :revisions, class_name: "Post::Revision", dependent: :destroy
  end

  # Locked before anything is read, so two saves a moment apart cannot both find the last revision old.
  def edit(attributes)
    with_lock do
      assign_attributes(attributes)

      if valid?
        record_revision
        save!
      end
    end
  end

  def edit_draft(attributes)
    with_lock do
      edit(attributes) if draft?
    end
  end

  # Only a draft's editor says it is one, so one left open on a post published since changes nothing.
  def edit_from_editor(attributes, of_draft:)
    if of_draft
      edit_draft(attributes)
    else
      edit(attributes)
    end
  end

  private
    def record_revision
      if content_changed?
        if last_revision_old?
          revisions.create!(title: title_in_database, body: body.body_in_database)
        else
          revisions.last.touch
        end
      end
    end

    def content_changed?
      title_changed? || body.body_changed?
    end

    def last_revision_old?
      revisions.empty? || revisions.last.created_at.before?(MINIMUM_TIME_BETWEEN_VERSIONS.ago)
    end
end

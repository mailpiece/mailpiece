module StatusHelper
  STATUS_SEMANTICS = {
    "draft" => "neutral",
    "scheduled" => "waiting",
    "published" => "muted",
    "sending" => "progress",
    "sent" => "muted",

    "active" => "success",
    "unconfirmed" => "warning",
    "unsubscribed" => "muted",
    "deactivated" => "muted",
    "bounced" => "error",

    "pending" => "waiting",
    "refused" => "error",
    "unverified" => "warning",

    "stale" => "warning"
  }.freeze

  STATUS_FORMS = {
    word: nil,
    badge: "status--badge"
  }.freeze

  QUIET_STATUSES = %w[ active sent published ].freeze

  def status_tag(status, form: :word, semantic: status_semantic(status), **options)
    tag.span status_word(status),
      class: class_names("status", "status--#{semantic}", STATUS_FORMS.fetch(form), options.delete(:class)), **options
  end

  def row_status_tag(status)
    if QUIET_STATUSES.include?(status.to_s)
      status_tag status, semantic: "muted"
    else
      status_tag status
    end
  end

  private
    def status_word(status)
      t("status_#{status}")
    end

    def status_semantic(status)
      STATUS_SEMANTICS.fetch(status.to_s, "neutral")
    end
end

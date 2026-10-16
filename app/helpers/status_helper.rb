module StatusHelper
  STATUS_SEMANTICS = {
    "draft" => "muted",
    "scheduled" => "waiting",
    "published" => "info",
    "sending" => "progress",
    "sent" => "success",

    "active" => "success",
    "unconfirmed" => "waiting",
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

  def status_tag(status, form: :word, **options)
    tag.span status_word(status),
      class: class_names("status", "status--#{status_semantic(status)}", STATUS_FORMS.fetch(form), options.delete(:class)), **options
  end

  private
    def status_word(status)
      t("status_#{status}")
    end

    def status_semantic(status)
      STATUS_SEMANTICS.fetch(status.to_s, "neutral")
    end
end

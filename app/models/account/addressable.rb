# An account answers at its number, and at a handle too once it picks one. The handle is an alias:
# the number never stops working. It is changed and cleared freely: the old name is free for another
# newsletter at once, and a link already mailed with it stops leading here.
#
# A newsletter may also have a domain of its own, where its public pages sit at the root and nothing else
# answers. It is changed and cleared freely too.
module Account::Addressable
  extend ActiveSupport::Concern

  HANDLE_FORMAT = /\A[a-z][a-z0-9-]*[a-z0-9]\z/
  HANDLE_LENGTH = 3..40
  DOMAIN_FORMAT = /\A(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z][a-z0-9-]*[a-z0-9]\z/
  DOMAIN_LENGTH = 253

  included do
    normalizes :handle, with: ->(value) { value.strip.downcase.presence }

    validates :handle, length: { in: HANDLE_LENGTH }, uniqueness: true, allow_nil: true,
      format: { with: HANDLE_FORMAT, message: ->(*) { I18n.t("account_handle_format") } },
      exclusion: { in: ->(account) { account.class.reserved_handles }, message: ->(*) { I18n.t("account_handle_taken") } }

    normalizes :domain, with: ->(value) { value.strip.downcase.presence }

    validates :domain, length: { maximum: DOMAIN_LENGTH }, uniqueness: true, allow_nil: true,
      format: { with: DOMAIN_FORMAT, message: ->(*) { I18n.t("account_domain_format") } },
      exclusion: { in: ->(account) { [ account.class.app_host ] }, message: :taken }
  end

  class_methods do
    # The first word of every address the app answers itself, so a handle never hides a screen.
    def reserved_handles
      Rails.application.routes.routes.filter_map { |route| route.path.spec.to_s[/\A\/([a-z0-9_-]+)/, 1] }.uniq + %w[ assets ]
    end

    # A newsletter that took the app's own host for its domain would leave nobody a way to sign in.
    def app_host
      Rails.application.routes.default_url_options[:host].to_s.downcase[/\A[^:]+/]
    end

    def answers_at?(host)
      host.present? && (host == app_host || exists?(domain: host))
    end
  end

  def slug
    handle ? "/#{handle}" : numbered_slug
  end

  def numbered_slug
    "/#{AccountSlug.encode(external_account_id)}"
  end

  # Where a reader finds its pages: at the root of its domain, or under its slug on the host that was asked.
  # A link from the app's side to a reader's page is built with this, and so is every link in its mail.
  def reader_url_options
    if domain
      { host: domain, script_name: nil }
    else
      { script_name: slug }
    end
  end
end

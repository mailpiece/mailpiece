class Post < ApplicationRecord
  include Deliverable, Editable, Linkable, Publishable, Rateable, Readable, Releasable, Schedulable, Sluggable, Thumbnailed

  EXCERPT_LENGTH = 400
  SUMMARY_LENGTH = 300

  belongs_to :account, default: -> { Current.account }
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_rich_text :body

  has_many :brought_subscribers, class_name: "Subscriber", foreign_key: :source_post_id, dependent: :nullify

  SEARCH_CONTENT_LIMIT = 32.kilobytes

  has_search index: :searchable, async: false, serializer: ->(post) {
    { account_id: post.account_id, title: post.title, content: post.searchable_content }
  }

  normalizes :title, with: ->(title) { title.squish.presence }
  normalizes :summary, with: ->(summary) { summary.squish.truncate(SUMMARY_LENGTH, separator: /\s/).presence }

  scope :preloaded, -> { with_rich_text_body.preload(:creator) }
  scope :reverse_chronologically, -> { order(created_at: :desc, id: :desc) }
  scope :matching, ->(terms, account:) do
    query = Search::Query.wrap(terms)

    if query.valid?
      search = Post.search(query.to_s).filter(account_id: account.id).limit(nil).to_native_query
      joins("INNER JOIN #{search.model.table_name} ON #{search.model.table_name}.searchable_id = posts.id")
        .merge(search.except(:select, :order))
    else
      none
    end
  end
  scope :dated_within, ->(range) { where(dated_at: range) }
  scope :earliest_dated_first, -> { order(dated_at: :asc) }
  scope :latest_dated_first, -> { order(dated_at: :desc) }

  # A released post keeps no schedule and a draft has no publication date, so a post has one date or none.
  before_save { self.dated_at = published_at || scheduled_posting_at }
  before_save :set_default_title, if: :published?

  class << self
    # The bar's JavaScript writes the same text, to compare the date picked with the one shown.
    def on_the_hour(day, hour)
      "#{day}T#{format("%02d", hour.to_i)}:00" if day.present?
    end
  end

  def state
    if sending?
      "sending"
    elsif sent?
      "sent"
    elsif published?
      "published"
    elsif scheduled?
      "scheduled"
    else
      "draft"
    end
  end

  # What the writer said the post is about, or else how it begins.
  def excerpt
    summary || paragraphs.join(" ").squish.truncate(EXCERPT_LENGTH, separator: /\s/)
  end

  # A draft's files too: a mail client loads a test email's images with no session.
  def publicly_accessible?
    true
  end

  # The web's reading, so what a box keeps for the email is never found.
  def searchable_content
    [ summary, body_on_the_web&.to_plain_text ].compact.join("\n").truncate_bytes(SEARCH_CONTENT_LIMIT, omission: "")
  end

  def lead_image
    if content = body_on_the_web
      content.attachables.find { |attachable| attachable.is_a?(ActionText::Attachables::RemoteImage) || (attachable.is_a?(ActiveStorage::Blob) && attachable.image?) }
    end
  end

  private
    def set_default_title
      self.title = account.in_locale { I18n.t("untitled") } if title.blank?
    end

    # Paragraphs only: the plain text of the whole body runs a heading straight into the sentence under it.
    def paragraphs
      if content = body_on_the_web
        content.fragment.find_all("p").reject { |paragraph| Post::Video.from(paragraph) }.map(&:text).select(&:present?).presence || [ content.to_plain_text ]
      else
        []
      end
    end
end

class Account < ApplicationRecord
  include Addressable, Avatar, Cancellable, Localizable, MultiTenantable, Welcoming

  DESCRIPTION_LENGTH = 500

  has_one :join_code, dependent: :destroy
  has_one :sender, dependent: :destroy
  has_many :users, dependent: :destroy
  has_many :posts, dependent: :destroy
  has_many :post_links, class_name: "Post::Link"
  has_many :post_deliveries, class_name: "Post::Delivery"
  has_many :subscribers, dependent: :destroy
  has_many :snippets, dependent: :destroy
  has_many :journey_emails, class_name: "Journey::Email", dependent: :destroy
  has_many :journey_runs, class_name: "Journey::Run", dependent: :delete_all
  has_many :subscriber_imports, class_name: "Subscriber::Import", dependent: :destroy

  has_rich_text :description
  has_rich_text :welcome_message

  scope :active, -> { where.missing(:cancellation) }

  before_create :assign_external_account_id
  after_create :create_join_code

  normalizes :subscription_return_url, with: ->(value) { value.strip.presence }

  validates :name, presence: true
  validate :description_is_short
  validates :subscription_return_url, length: { maximum: 255 },
    format: { with: /\A#{URI::DEFAULT_PARSER.make_regexp(%w[ https ])}\z/, message: ->(*) { I18n.t("account_return_url_format") } }, allow_nil: true

  class << self
    def create_with_owner(account:, owner:)
      create!(**account).tap do |account|
        account.users.create!(role: :system, name: "System")
        account.users.create!(**owner.with_defaults(role: :owner, verified_at: Time.current))
      end
    end
  end

  def account
    self
  end

  def system_user
    users.find_by!(role: :system)
  end

  def active?
    !cancelled?
  end

  def sends_mail?
    sender.present? && sender.complete?
  end

  def journeys
    Journey::TRIGGERS.map { |trigger| journey_triggered_by(trigger) }
  end

  def journey_triggered_by(trigger)
    Journey.new(self, trigger)
  end

  private
    # Read through the association: asking for the description builds an empty one, which would then be saved.
    def description_is_short
      if rich_text_description && rich_text_description.to_plain_text.length > DESCRIPTION_LENGTH
        errors.add :description, :too_long, count: DESCRIPTION_LENGTH
      end
    end

    def assign_external_account_id
      self.external_account_id ||= ExternalIdSequence.next
    end
end

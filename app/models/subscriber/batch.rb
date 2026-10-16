# Several addresses, typed or read from a file, added together or not at all.
class Subscriber::Batch
  include ActiveModel::Model

  Row = Data.define(:subscriber, :ticked)

  BLANK_ROW_COUNT = 2
  REFUSALS = {
    unsubscribed: "subscribers_batch_refusal_unsubscribed",
    bounced: "subscribers_batch_refusal_bounced",
    deactivated: "subscribers_batch_refusal_deactivated"
  }.freeze

  attr_reader :account, :import, :rows

  def initialize(account:, rows: nil, import: nil)
    @account, @import = account, import
    @rows = (rows || rows_to_start_with).map { build_row(it.to_h.stringify_keys) }
  end

  def save
    if to_add.none?
      errors.add :base, I18n.t("subscribers_batch_error_empty")
      false
    else
      add_all_or_none
    end
  end

  def count
    to_add.size
  end

  def sole_subscriber
    account.subscribers.find_by(email: to_add.first.email) if to_add.one?
  end

  def already_on_the_list
    @already_on_the_list ||= found.select { registered?(it) }
  end

  def match_on_the_list(row)
    registered[row["email"]]
  end

  def not_addresses
    @not_addresses ||= found.reject { registered?(it) || address?(it) }
  end

  def found_count
    found.size
  end

  def none_to_add?
    found.any? && rows.all? { it.ticked.nil? }
  end

  def blank_row
    Row.new subscriber: Subscriber.new, ticked: nil
  end

  private
    def rows_to_start_with
      found.select { addable?(it) }.map { it.merge("added" => "1") }.presence || Array.new(BLANK_ROW_COUNT) { {} }
    end

    def found
      @found ||= import&.completed? ? import.rows.to_a : []
    end

    def addable?(row)
      address?(row) && !registered?(row)
    end

    def address?(row)
      Subscriber.new(account: account, email: row["email"]).valid?
    end

    # An unconfirmed address is on the list and still worth adding: adding it confirms it.
    def registered?(row)
      match_on_the_list(row).present? && !match_on_the_list(row).unconfirmed?
    end

    def registered
      @registered ||= account.subscribers.where(email: found.pluck("email")).index_by(&:email)
    end

    # A row read from a file carries a box, sent as "1" or "0"; a typed row has none and is added unless left blank.
    def build_row(attributes)
      Row.new subscriber: account.subscribers.new(attributes.slice("email")), ticked: attributes["added"]&.then { it == "1" }
    end

    def to_add
      @to_add ||= rows.reject { it.ticked == false || it.subscriber.email.blank? }.map(&:subscriber)
    end

    # Every row is tried, so each shows its own error, and one failing takes the rest back with it.
    def add_all_or_none
      added = false

      Subscriber.transaction do
        to_add.each { add(it) }
        raise ActiveRecord::Rollback unless to_add.all? { it.errors.none? }

        import&.destroy!
        added = true
      end

      added
    end

    def add(candidate)
      if candidate.valid?
        subscriber = account.subscribers.add(candidate.email)
        candidate.errors.add :email, I18n.t(REFUSALS.fetch(subscriber.status)) unless subscriber.listed?
      end
    end
end

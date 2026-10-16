# A file of addresses handed over to fill the rows of the bulk add page. It is working state only: it goes once
# its rows are added, and on its own once abandoned.
class Subscriber::Import < ApplicationRecord
  CONTENT_TYPES = %w[ text/csv text/plain application/vnd.ms-excel ].freeze
  MAX_FILE_SIZE = 1.megabyte
  ROWS_LIMIT = 1_000
  # Only the heading: a template sent back as it came fills no rows.
  TEMPLATE = "email\n"

  broadcasts_refreshes

  belongs_to :account
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  has_one_attached :file, dependent: :purge_later

  enum :status, %w[ pending processing completed failed ].index_by(&:itself), default: :pending
  enum :failure_reason, %w[ too_long unreadable ].index_by(&:itself), prefix: :failed_due_to, scopes: false

  validate :file_is_a_list

  scope :expired, -> { where(created_at: ...1.day.ago) }

  def self.cleanup
    expired.destroy_all
  end

  def process_later
    Subscriber::Import::ProcessJob.perform_later(self)
  end

  # Whatever goes wrong, the import ends completed or failed, so the screen waiting on it never waits for ever.
  def process
    processing!

    if emails.size > ROWS_LIMIT
      update! status: :failed, failure_reason: :too_long
    else
      update! status: :completed, rows: emails.map { |email| { "email" => email } }
    end
  rescue StandardError => error
    Rails.logger.error "Reading #{self.class.name} #{id} failed: #{error.class}: #{error.message}"
    update! status: :failed, failure_reason: :unreadable
  end

  def read?
    completed? || failed?
  end

  private
    def emails
      @emails ||= cells.map { |cell| Subscriber.normalize_value_for(:email, cell) }.compact_blank.uniq
    end

    # The column headed "email" when the first line names one, else the first column, a line being one address.
    def cells
      if column = lines.first.to_a.index { |cell| cell.casecmp?("email") }
        lines.drop(1).map { |line| line[column].to_s }
      else
        lines.map { |line| line.first.to_s }
      end
    end

    def lines
      @lines ||= text.lines.map { |line| line.split(/[,;\t]/).map { |cell| cell.strip.delete_prefix('"').delete_suffix('"').strip } }
    end

    def text
      file.download.force_encoding(Encoding::UTF_8).delete_prefix("﻿").tap do |text|
        raise ArgumentError, "not text" unless text.valid_encoding?
      end
    end

    def file_is_a_list
      if !file.attached?
        errors.add :file, I18n.t("subscribers_import_file_missing")
      elsif !file.content_type.in?(CONTENT_TYPES)
        errors.add :file, I18n.t("subscribers_import_file_wrong_type")
      elsif file.byte_size > MAX_FILE_SIZE
        errors.add :file, I18n.t("subscribers_import_file_too_large")
      end
    end
end

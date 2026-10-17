class Account::Sender < ApplicationRecord
  REQUIRED_ATTRIBUTES = %i[ from_name from_address transport ].freeze
  RELAY_ATTRIBUTES = %i[ relay_url relay_token ].freeze
  SMTP_ATTRIBUTES = %i[ smtp_address smtp_port smtp_username smtp_password ].freeze
  TRANSPORT_ATTRIBUTES = [ :transport, *RELAY_ATTRIBUTES, *SMTP_ATTRIBUTES ].freeze

  belongs_to :account

  encrypts :relay_token, :smtp_password

  normalizes :from_name, with: ->(value) { value.strip }
  normalizes :from_address, :reply_to_address, with: ->(value) { value.strip.downcase }
  normalizes :smtp_username, with: ->(value) { value.strip.presence }

  validates :from_address, :reply_to_address, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :relay_url, :relay_token, presence: true, if: :relay?
  validates :relay_url, format: { with: /\A#{URI::DEFAULT_PARSER.make_regexp(%w[ http https ])}\z/ }, allow_blank: true
  validates :smtp_address, :smtp_port, presence: true, if: :smtp?
  validates :smtp_password, presence: true, if: -> { smtp? && smtp_username.present? }
  validate :credentials_set_once, if: -> { persisted? && !transport_changed? }

  def complete?
    missing.empty?
  end

  def missing
    REQUIRED_ATTRIBUTES.select { |attribute| self[attribute].blank? }
  end

  def from
    ActionMailer::Base.email_address_with_name(from_address, from_name)
  end

  def domain
    from_address.to_s.split("@").last
  end

  def reply_to
    ActionMailer::Base.email_address_with_name(reply_to_address, from_name) if reply_to_address.present?
  end

  def relay?
    transport == "relay"
  end

  def smtp?
    transport == "smtp"
  end

  def use_relay(settings)
    replace_transport settings.merge(transport: "relay")
  end

  def use_smtp_server(settings)
    replace_transport settings.merge(transport: "smtp")
  end

  def stop_sending
    update! TRANSPORT_ATTRIBUTES.index_with(nil)
  end

  private
    def replace_transport(settings)
      assign_attributes TRANSPORT_ATTRIBUTES.index_with(nil) unless transport == settings[:transport]
      assign_attributes settings
      self.smtp_password = nil if smtp_username.blank?
      save
    end

    # A token or password is never shown again, so it is set with its transport and goes when the transport does.
    def credentials_set_once
      errors.add :relay_token, :relay_set_once if replacing_stored?(:relay_token)
      errors.add :smtp_password, :smtp_set_once if replacing_stored?(:smtp_password)
    end

    def replacing_stored?(credential)
      attribute_changed?(credential) && attribute_in_database(credential).present? && self[credential].present?
    end
end

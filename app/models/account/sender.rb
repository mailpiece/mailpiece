class Account::Sender < ApplicationRecord
  REQUIRED_ATTRIBUTES = %i[ from_name from_address ].freeze

  belongs_to :account

  normalizes :from_name, with: ->(value) { value.strip }
  normalizes :from_address, :reply_to_address, with: ->(value) { value.strip.downcase }

  validates :from_address, :reply_to_address, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # A sender is who the newsletter writes as. How its mail leaves is the install's business, in ENV.
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

  def reply_address
    reply_to_address.presence || from_address
  end
end

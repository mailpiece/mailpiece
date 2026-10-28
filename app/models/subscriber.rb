class Subscriber < ApplicationRecord
  include Confirmable, Deactivatable, Journeying, Statuses

  belongs_to :account
  belongs_to :source_post, class_name: "Post", optional: true
  # Destroyed one by one, so each post's count of deliveries follows.
  has_many :deliveries, class_name: "Post::Delivery", dependent: :destroy

  has_secure_token :token

  normalizes :email, with: ->(value) { value.strip.downcase }
  normalizes :referrer, with: ->(referrer) { referrer.truncate(255, omission: "").presence }

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 255 }

  scope :reverse_chronologically, -> { order(created_at: :desc, id: :desc) }
  scope :matching, ->(query) { where("email LIKE ?", "%#{query}%") }

  # Only someone who was on the list starts the unsubscribe journey.
  def unsubscribe
    unless unsubscribed_at?
      transaction do
        leaving_the_list = active?
        update!(unsubscribed_at: Time.current)
        start_journey "subscriber_unsubscribed" if leaving_the_list
      end
    end
  end

  def referrer_host
    URI.parse(referrer).host if referrer.present?
  rescue URI::InvalidURIError
    nil
  end

  # Marked by an admin, or by a provider through the API: an address mail no longer reaches. Nothing is counted here.
  def bounce
    update!(bounced_at: Time.current) unless bounced_at?
  end
end

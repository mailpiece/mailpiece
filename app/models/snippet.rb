# A piece a newsletter writes once and pastes into many posts. A post holds a copy and nothing of the snippet itself.
class Snippet < ApplicationRecord
  belongs_to :account, default: -> { Current.account }

  has_rich_text :content

  normalizes :name, with: ->(name) { name.squish }

  validates :name, presence: true

  scope :alphabetically, -> { order(:name, :id) }
end

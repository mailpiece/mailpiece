module Post::Rateable
  extend ActiveSupport::Concern

  included do
    has_many :ratings, class_name: "Post::Rating", dependent: :delete_all
  end

  def rate_by(subscriber, choice)
    ratings.create_or_find_by(subscriber: subscriber) { it.choice = choice }.tap { it.update!(choice: choice) }
  end
end

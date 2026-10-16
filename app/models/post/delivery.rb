class Post::Delivery < ApplicationRecord
  include SentOnce

  belongs_to :account, default: -> { post.account }
  belongs_to :post, counter_cache: :deliveries_count
  belongs_to :subscriber

  generates_token_for :rating, expires_in: 1.month

  private
    def delivery_job
      Post::DeliveryJob
    end

    def mail
      PostMailer.issue(post, subscriber, delivery: self)
    end
end

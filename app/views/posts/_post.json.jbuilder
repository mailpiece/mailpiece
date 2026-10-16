json.(post, :id, :title, :summary, :slug, :deliveries_count)
json.body post.body.to_plain_text
json.body_html post.body.to_s
json.published post.published?
json.visibility post.visibility
json.published_at post.published_at&.utc
json.sent_at post.sent_at&.utc
json.scheduled_posting_at post.scheduled_posting_at&.utc
json.scheduled_delivery post.scheduled_delivery
json.created_at post.created_at.utc
json.updated_at post.updated_at.utc
json.url post_url(post, format: :json)
json.public_url public_post_url(post.public_param, **Current.account.reader_url_options) if post.published? && post.on_the_web?
json.creator post.creator, partial: "users/user", as: :user

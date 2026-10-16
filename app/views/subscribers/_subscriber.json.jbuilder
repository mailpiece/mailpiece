json.(subscriber, :id, :email)
json.status subscriber.active? ? "confirmed" : subscriber.status
json.confirmed_at subscriber.confirmed_at&.utc
json.unsubscribed_at subscriber.unsubscribed_at&.utc
json.bounced_at subscriber.bounced_at&.utc
json.deactivated_at subscriber.deactivated_at&.utc
if subscriber.source_post
  json.source_post do
    json.(subscriber.source_post, :id, :code, :title)
    json.url post_url(subscriber.source_post, format: :json)
  end
else
  json.source_post nil
end
json.referrer subscriber.referrer
json.created_at subscriber.created_at.utc
json.url subscriber_url(subscriber, format: :json)

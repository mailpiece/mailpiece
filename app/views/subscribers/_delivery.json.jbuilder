json.(delivery, :id)
json.post do
  json.(delivery.post, :id, :title)
  json.url post_url(delivery.post, format: :json)
end
json.status delivery.state
json.sent_at delivery.sent_at&.utc
json.refused_at delivery.refused_at&.utc
json.created_at delivery.created_at.utc

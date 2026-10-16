json.cache! account do
  json.(account, :id, :name)
  json.slug account.numbered_slug
  json.description account.description.to_plain_text
  json.created_at account.created_at.utc
end

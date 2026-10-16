json.(link, :id, :code, :text, :original_url, :url)
json.stale link.stale?
json.created_at link.created_at.utc
json.updated_at link.updated_at.utc

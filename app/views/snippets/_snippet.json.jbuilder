json.(snippet, :id, :name)
json.content snippet.content.to_plain_text
json.content_html snippet.content.to_s
json.created_at snippet.created_at.utc
json.updated_at snippet.updated_at.utc
json.url snippet_url(snippet, format: :json)

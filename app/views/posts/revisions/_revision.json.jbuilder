json.(revision, :id)
json.created_at revision.created_at.utc
json.updated_at revision.updated_at.utc
json.url post_revision_url(revision.post, revision, format: :json)
json.creator revision.creator, partial: "users/user", as: :user

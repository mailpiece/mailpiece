namespace :search do
  desc "Reindex all posts in the search index"
  task reindex: :environment do
    puts "Clearing search records..."
    # Raw deletes rather than a per-account remove: a row whose account is gone has no account to visit.
    ActiveRecord::Base.connection.execute("DELETE FROM search_records")
    ActiveRecord::Base.connection.execute("DELETE FROM search_records_fts")

    puts "Reindexing posts..."
    Post.includes(:rich_text_body).find_each(&:reindex)

    puts "Done! Reindexed #{Post.count} posts."
  end
end

atom_feed language: I18n.locale.to_s, root_url: root_url, url: public_feed_url do |feed|
  feed.title Current.account.name
  feed.updated @page.records.map(&:updated_at).max

  @page.records.each do |post|
    feed.entry post, url: public_post_url(post.public_param), published: post.published_at, updated: post.updated_at do |entry|
      entry.title post.title
      entry.content post_web_html(post).to_s, type: "html"
      entry.author { |author| author.name post.creator.name }
    end
  end
end

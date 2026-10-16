xml.instruct!
xml.urlset xmlns: "http://www.sitemaps.org/schemas/sitemap/0.9" do
  xml.url do
    xml.loc root_url
    xml.lastmod @posts.maximum(:updated_at).utc.iso8601 if @posts.any?
  end

  @posts.each do |post|
    xml.url do
      xml.loc public_post_url(post.public_param)
      xml.lastmod post.updated_at.utc.iso8601
    end
  end
end

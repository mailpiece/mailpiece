module ShareHelper
  def post_share_tags(post)
    image = post_share_image(post)
    url = public_post_url(post.public_param, **Current.account.reader_url_options)

    share_tags title: "#{post.title} | #{Current.account.name}", description: post.excerpt, url: url,
      image: image || account_share_image, card: (image ? "summary_large_image" : "summary"), type: "article", published_at: post.published_at,
      structured_data: { "@type": "BlogPosting", headline: post.title, mainEntityOfPage: url,
        datePublished: post.published_at&.utc&.iso8601, dateModified: post.updated_at.utc.iso8601,
        author: { "@type": "Person", name: post.creator.name },
        publisher: { "@type": "Organization", name: Current.account.name, url: root_url(**Current.account.reader_url_options) } }
  end

  def newsletter_share_tags
    share_tags title: Current.account.name, description: Current.account.description.to_plain_text.squish, url: root_url(**Current.account.reader_url_options),
      image: account_share_image, card: "summary", type: "website",
      structured_data: { "@type": "WebSite", name: Current.account.name }
  end

  private
    # The canonical address is the newsletter's domain when it has one, wherever the page was asked.
    def share_tags(title:, description:, url:, image:, card:, type:, structured_data:, published_at: nil)
      safe_join [
        tag.link(rel: "canonical", href: url),
        tag.link(rel: "sitemap", type: "application/xml", href: public_sitemap_url),
        (tag.meta(name: "description", content: description) if description.present?),
        tag.meta(property: "og:type", content: type),
        tag.meta(property: "og:site_name", content: Current.account.name),
        tag.meta(property: "og:title", content: title),
        (tag.meta(property: "og:description", content: description) if description.present?),
        tag.meta(property: "og:url", content: url),
        (tag.meta(property: "og:image", content: image) if image),
        (tag.meta(property: "article:published_time", content: published_at.utc.iso8601) if published_at),
        tag.meta(name: "twitter:card", content: card),
        structured_data_tag(structured_data.merge(description: description, url: url, image: image))
      ].compact, "\n"
    end

    # json_escape keeps a title holding </script> inside the tag, whatever to_json is set to escape.
    def structured_data_tag(data)
      tag.script json_escape({ "@context": "https://schema.org" }.merge(data).compact_blank.to_json).html_safe, type: "application/ld+json"
    end

    # The address the email gives the same picture: public, and it does not expire.
    def post_share_image(post)
      case image = post.lead_image
      when ActionText::Attachables::RemoteImage then image.url
      when ActiveStorage::Blob then rails_storage_proxy_url(image)
      end
    end

    def account_share_image
      account_avatar_url if Current.account.avatar_attached?
    end
end

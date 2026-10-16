# What a mail client is sent of a text: only the markup one shows, styled inline since it reads no stylesheet,
# with each video a poster and each link of a mailed issue leading through its redirect.
#
# The block is the view's: handed an attachment or a video it answers with the markup to draw it, and handed a
# link, with the address of its redirect. Nothing here builds an address.
class Post::Readable::Email
  TAGS = %w[
    p br h1 h2 h3 h4 h5 h6 ul ol li blockquote a img pre code strong b em i u s del mark sub sup hr
    figure figcaption div span table thead tbody tr th td
  ].freeze
  ATTRIBUTES = %w[ href src alt width start colspan rowspan ].freeze

  STYLES = {
    "p" => "margin: 0 0 16px;",
    "h1" => "font-family: Georgia, 'Times New Roman', serif; font-size: 26px; line-height: 1.25; margin: 32px 0 12px;",
    "h2" => "font-family: Georgia, 'Times New Roman', serif; font-size: 22px; line-height: 1.25; margin: 28px 0 12px;",
    "h3" => "font-family: Georgia, 'Times New Roman', serif; font-size: 19px; line-height: 1.3; margin: 24px 0 8px;",
    "h4" => "font-family: Georgia, 'Times New Roman', serif; font-size: 17px; line-height: 1.3; margin: 24px 0 8px;",
    "h5" => "font-family: Georgia, 'Times New Roman', serif; font-size: 17px; line-height: 1.3; margin: 24px 0 8px;",
    "h6" => "font-family: Georgia, 'Times New Roman', serif; font-size: 17px; line-height: 1.3; margin: 24px 0 8px;",
    "ul" => "margin: 0 0 16px; padding: 0 0 0 24px;",
    "ol" => "margin: 0 0 16px; padding: 0 0 0 24px;",
    "li" => "margin: 0 0 6px;",
    "blockquote" => "border-left: 3px solid #d1d5dc; color: #4a4a4a; margin: 0 0 16px; padding: 0 0 0 16px;",
    "a" => "color: #0069ff; text-decoration: underline;",
    "img" => "border: 0; display: block; height: auto; margin: 0 auto; max-width: 100%;",
    "pre" => "background-color: #f4f4f5; border-radius: 6px; font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 14px; line-height: 1.45; margin: 0 0 16px; padding: 12px 16px; white-space: pre-wrap; word-break: break-word;",
    "code" => "font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 14px;",
    "hr" => "border: 0; border-top: 1px solid #d1d5dc; margin: 24px 0;",
    "figure" => "margin: 0 0 16px; text-align: center;",
    "figcaption" => "color: #737374; font-size: 14px; margin: 8px 0 0;",
    "table" => "border-collapse: collapse; margin: 0 0 16px; width: 100%;",
    "th" => "border: 1px solid #d1d5dc; padding: 6px 10px; text-align: left;",
    "td" => "border: 1px solid #d1d5dc; padding: 6px 10px;"
  }.freeze

  # A video with no picture to show. The sanitizer keeps no style or class, so it is found by where it sits.
  POSTER_SELECTOR = "figure > a > span"
  POSTER_STYLE = "border: 1px solid #d1d5dc; border-radius: 6px; display: block; padding: 48px 16px;"

  def initialize(content, links:, &view)
    @content, @links, @view = content, links, view
  end

  def html
    ActionText::Fragment.from_html(sanitized_html).update do |source|
      Post::Video.replace_each_in(source, &@view)
      redirect_links(source)
      style(source)
    end.to_html.html_safe
  end

  def text
    fragment = @content.render_attachments(&@view).fragment.update { |source| redirect_links(source) }

    ActionText::Content.new(fragment, canonicalize: false).to_markdown
  end

  private
    def sanitized_html
      ActionView::Base.safe_list_sanitizer.sanitize @content.render_attachments(&@view).to_html, tags: TAGS, attributes: ATTRIBUTES
    end

    # A link of a mailed issue goes out through its redirect, after a video was recognised by its own address.
    # A post not mailed yet has no rows, so its test issue keeps the addresses as written.
    def redirect_links(source)
      links = @links.index_by(&:original_url)

      source.css("a[href]").each do |node|
        if link = links[node["href"]]
          node["href"] = @view.call(link)
        end
      end
    end

    def style(source)
      source.css(STYLES.keys.join(", ")).each { |node| node["style"] = STYLES[node.name] }
      source.css(POSTER_SELECTOR).each { |node| node["style"] = POSTER_STYLE }
    end
end

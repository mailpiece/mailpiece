# The text as a reader gets it, on the web or in the email: what a box kept for one audience holds is ordinary text
# for that one, and nothing for the other.
module Post::Readable
  extend ActiveSupport::Concern

  def body_on_the_web
    body_for :web
  end

  def body_in_email
    body_for :email
  end

  # The page and the feed's markup, each video drawn by the block. It is drawn after the text is sanitized, so
  # what the view writes for one is kept whole.
  def html_on_the_web(&view)
    if content = body_on_the_web
      ActionText::Fragment.from_html(content.to_s).update do |source|
        Post::Video.replace_each_in(source, &view)
      end.to_html.html_safe
    end
  end

  def html_in_email(&view)
    if content = body_in_email
      Email.new(content, links: links, &view).html
    end
  end

  def text_in_email(&view)
    if content = body_in_email
      Email.new(content, links: links, &view).text
    else
      ""
    end
  end

  private
    def body_for(medium)
      if content = body.body
        ActionText::Content.new open_boxes(content.fragment, medium), canonicalize: false
      end
    end

    # A box of a name that is no audience's is opened for everyone, so nothing written is ever lost to a reader.
    def open_boxes(fragment, medium)
      fragment.update do |source|
        source.css("aside[data-audience]").each do |box|
          audience = Post::Audience.named(box["data-audience"])

          if audience.nil? || audience.medium == medium
            box.replace box.children
          else
            box.unlink
          end
        end
      end
    end
end

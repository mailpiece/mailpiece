module Post::Linkable
  extend ActiveSupport::Concern

  included do
    has_many :links, -> { order(:id) }, class_name: "Post::Link", dependent: :delete_all
  end

  # One row per address, however often it is linked or this is called: the row's code is what the email carries.
  def record_links
    email_links.each do |address, text|
      links.find_or_create_by!(original_url: address) { |link| link.assign_attributes url: address, text: text }
    end
  end

  # Each address the email links to, with the text of the first link to it.
  def email_links
    if content = body_in_email
      content.fragment.find_all("a[href]").each_with_object({}) do |link, addresses|
        addresses[link["href"]] ||= link.text if link["href"].match?(Post::Link::WEB_ADDRESS)
      end
    else
      {}
    end
  end
end

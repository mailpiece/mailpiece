# Where a draft goes when it is released: a visibility, and whether it is mailed to the list.
class Post::Destination
  attr_reader :name, :visibility

  class << self
    # In the order they are offered.
    def all
      @all ||= [
        new("web_and_email", visibility: "listed", mailed: true),
        new("email", visibility: "email_only", mailed: true),
        new("web", visibility: "listed", mailed: false),
        new("link", visibility: "unlisted", mailed: false)
      ].freeze
    end
  end

  def initialize(name, visibility:, mailed:)
    @name, @visibility, @mailed = name, visibility, mailed
  end

  def label
    I18n.t("posts_destination_#{name}")
  end

  def mailed?
    @mailed
  end
end

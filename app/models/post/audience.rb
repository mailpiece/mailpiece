# Who a box in a post is for when it is not for every reader: the web's or the email's. The writer types in the box,
# which is kept in the text as an <aside> naming its audience. What it does to the text is Post::Readable's to say.
class Post::Audience
  MEDIA = %i[ web email ].freeze

  attr_reader :medium

  class << self
    def all
      @all ||= MEDIA.map { |medium| new(medium) }
    end

    # By the name its box carries in the text.
    def named(name)
      all.find { |audience| audience.name == name }
    end
  end

  def initialize(medium)
    @medium = medium
  end

  # Kept in the post's text, so it is the same word whatever language the newsletter is written in.
  def name
    medium.to_s
  end

  def label
    I18n.t("posts_audience_#{medium}")
  end

  # The word that finds it in the editor's menu, typed after the slash.
  def command
    I18n.t("posts_audience_#{medium}_command")
  end
end

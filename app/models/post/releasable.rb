module Post::Releasable
  extend ActiveSupport::Concern

  def destinations
    Post::Destination.all.select { |destination| mailable? || !destination.mailed? }
  end

  def destination_named(name)
    destinations.find { |destination| destination.name == name }
  end

  # A request that names no destination is the JSON's, which is held to the post's own visibility and not to what
  # the editor offers: it may schedule a mailing before there is anyone to mail.
  def destination_for(name, mailed: false)
    if name.present?
      destination_named(name)
    else
      Post::Destination.new(nil, visibility: visibility, mailed: mailed)
    end
  end

  # The one proposed: what a schedule holds, or else the widest the draft's visibility allows.
  def destination
    reachable = destinations.select { |destination| destination.visibility == visibility }
    reachable.find { |destination| destination.mailed? == mailing_proposed? } || reachable.first || destinations.first
  end

  def release(to: nil)
    if published?
      deliver
    else
      release_to to
    end
  end

  # The list may have emptied since the choice was offered, and an email-only post is never published unsent.
  def release_to(destination)
    with_lock do
      if draft? && destinations.include?(destination)
        update! visibility: destination.visibility

        if destination.mailed?
          deliver
        else
          publish
        end
      end
    end
  end

  def schedule_to(destination, at:)
    with_lock do
      schedule at: at, deliver: destination.mailed?, visibility: destination.visibility
    end
  end

  # False only when the post says why not: a post that already has its page is answered as done.
  def publish_to(destination, at: nil)
    if published?
      publish_on_the_web
    elsif at.present?
      backdate at: at, visibility: destination.visibility
    else
      with_lock do
        update! visibility: destination.visibility
        publish
      end
    end

    errors.none?
  end

  private
    def mailable?
      deliverable? && account.subscribers.active.exists?
    end

    def mailing_proposed?
      if scheduled?
        scheduled_delivery?
      else
        true
      end
    end
end

module SubscribersHelper
  def subscriber_meta(subscriber)
    case subscriber.status
    when :bounced
      t "subscribers_row_bounced_html", date: local_datetime_tag(subscriber.bounced_at, style: :date)
    when :deactivated
      t "subscribers_row_deactivated_html", date: local_datetime_tag(subscriber.deactivated_at, style: :date)
    when :unsubscribed
      t "subscribers_row_unsubscribed_html", date: local_datetime_tag(subscriber.unsubscribed_at, style: :date)
    when :active
      t "subscribers_row_subscribed_html", date: local_datetime_tag(subscriber.created_at, style: :date)
    else
      t "subscribers_row_unconfirmed_html", date: local_datetime_tag(subscriber.created_at, style: :date)
    end
  end

  def subscriber_state_sentence(subscriber)
    if subscriber.bounced?
      t "subscribers_state_bounced_html", date: local_datetime_tag(subscriber.bounced_at, style: :date)
    elsif subscriber.deactivated?
      t "subscribers_state_deactivated_html", date: local_datetime_tag(subscriber.deactivated_at, style: :date)
    elsif subscriber.unsubscribed?
      t "subscribers_state_unsubscribed_html", date: local_datetime_tag(subscriber.unsubscribed_at, style: :date)
    elsif subscriber.active?
      t "subscribers_state_confirmed_html", date: local_datetime_tag(subscriber.confirmed_at, style: :date)
    else
      t("subscribers_state_unconfirmed")
    end
  end

  # Only what the row still holds, where a date is overwritten when the same thing happens again, and what its
  # posts' and journeys' rows say, each with where it leads if anywhere. Listed in the order they happen, which
  # settles two events of the same second.
  def subscriber_events(subscriber)
    [
      subscriber_subscribed_event(subscriber),
      [ subscriber.confirmation_sent_at, t("subscribers_event_confirmation_sent") ],
      [ subscriber.confirmed_at, t("status_active") ],
      *subscriber.deliveries.preload(:post).map { subscriber_post_event(it) },
      *subscriber.journey_deliveries.preload(:email).map { subscriber_journey_event(it) },
      *subscriber.journey_runs.not_in_progress.map { subscriber_journey_run_event(it) },
      [ subscriber.unsubscribed_at, t("status_unsubscribed") ],
      [ subscriber.bounced_at, t("subscribers_event_bounced") ],
      [ subscriber.deactivated_at, t("subscribers_event_deactivated") ]
    ].select(&:first).sort_by.with_index { |(time, _), position| [ time.to_i, position ] }.reverse
  end

  # The referrer is whatever the browser sent, so it is named by its host and never linked.
  def subscriber_subscribed_event(subscriber)
    if post = subscriber.source_post
      [ subscriber.created_at, t("subscribers_event_subscribed_from_post", title: post_title(post)), edit_post_path(post) ]
    elsif host = subscriber.referrer_host
      [ subscriber.created_at, t("subscribers_event_subscribed_from_host", host: host) ]
    else
      [ subscriber.created_at, t("subscribers_event_subscribed") ]
    end
  end

  def subscriber_post_event(delivery)
    [ delivery_time(delivery), t("subscribers_event_delivery_#{delivery.state}", subject: post_title(delivery.post)), edit_post_path(delivery.post) ]
  end

  def subscriber_journey_event(delivery)
    [ delivery_time(delivery), t("subscribers_event_delivery_#{delivery.state}", subject: journey_email_subject(delivery.email)) ]
  end

  def subscriber_journey_run_event(run)
    [ run.ended_at, t("subscribers_event_run_#{run.state}", journey: run.journey.label) ]
  end

  def delivery_time(delivery)
    delivery.sent_at || delivery.refused_at || delivery.deliver_at || delivery.created_at
  end

  # A person never sees or fills the "reference" field: an address that arrives with it is dropped.
  def subscribe_form_snippet
    <<~HTML
      <form action="#{public_embedded_subscription_url(**Current.account.reader_url_options)}" method="post">
        <label for="mailpiece-email">#{t("subscribers_snippet_email_label")}</label>
        <input type="email" id="mailpiece-email" name="email" autocomplete="email" required>
        <input type="text" name="reference" tabindex="-1" autocomplete="off" aria-hidden="true" hidden>
        <button type="submit">#{t("subscribers_snippet_button")}</button>
      </form>
    HTML
  end
end

module PostsHelper
  def post_title(post)
    post.title.presence || t("untitled")
  end

  def post_meta(post)
    safe_join [ post_progress(post), post_visibility(post) ].compact, " · "
  end

  # The editor writes the state of a save over the progress, so a schedule stands beside it and not in it.
  def post_bar_progress(post)
    post_progress(post) unless post.scheduled?
  end

  def post_bar_detail(post)
    safe_join [
      (t("posts_progress_for_html", schedule: post_schedule_description(post)) if post.scheduled?),
      post_visibility(post) || (t("posts_listed") if post.published?)
    ].compact, " · "
  end

  # The parts stand with nothing between them, so the dot the stylesheet joins them with never shows beside an
  # empty one.
  def post_bar_state(post)
    tag.span class: "post-actions__note post-actions__state txt-small txt-subtle" do
      safe_join [
        tag.span(post.draft? ? t("status_#{post.state}") : nil),
        tag.span(post_bar_progress(post), class: "post-actions__progress", role: "status", data: { save_state_target: "label" }),
        tag.span(post_bar_detail(post), class: "post-actions__detail", id: dom_id(post, :detail))
      ]
    end
  end

  # A draft saves itself in the background; a published post is saved by hand, and its shortcut presses "Save".
  def post_editor_data(post)
    {
      controller: token_list("autoresize advance-to-editor save-state", "auto-save": post.draft?),
      save_state_dirty_value: t("posts_save_dirty"),
      save_state_saving_value: t("posts_save_saving"),
      save_state_saved_value: t("saved"),
      save_state_failed_value: t("posts_save_failed"),
      action: token_list(
        "turbo:submit-end->post-bar#submitted input->save-state#changed lexxy:change->save-state#changed",
        "turbo:submit-start->save-state#submitting turbo:submit-end->save-state#submitted",
        "auto-save:saving->save-state#saving auto-save:saved->save-state#saved auto-save:failed->save-state#failed": post.draft?,
        "keydown.meta+s@document->auto-save#submitNow keydown.ctrl+s@document->auto-save#submitNow": post.draft?,
        "keydown.meta+s@document->save-state#save keydown.ctrl+s@document->save-state#save": !post.draft?
      )
    }
  end

  def post_visibility(post)
    if post.unlisted?
      t("posts_unlisted")
    elsif post.email_only?
      t("posts_email_only")
    end
  end

  def post_schedule_description(post)
    if post.scheduled_delivery?
      t("posts_schedule_with_sending_html", time: post_schedule_time(post))
    else
      t("posts_schedule_without_sending_html", time: post_schedule_time(post))
    end
  end

  def post_destination_action(destination, recipients_count)
    case destination.name
    when "web_and_email"
      t("posts_release_publish_and_send", count: recipients_count, number: number_with_delimiter(recipients_count))
    when "email" then post_send_action(recipients_count)
    when "web" then t("posts_release_publish")
    when "link" then t("posts_release_publish_by_link")
    end
  end

  def post_destination_past_action(destination, recipients_count)
    if destination.name == "web_and_email"
      t("posts_release_publish")
    else
      post_destination_action(destination, recipients_count)
    end
  end

  def post_destination_schedule_action(destination, recipients_count)
    if destination.mailed?
      t("posts_release_schedule_and_send", count: recipients_count, number: number_with_delimiter(recipients_count))
    else
      t("posts_release_schedule")
    end
  end

  def post_destination_data(destination, recipients_count)
    {
      post_bar_target: "destination",
      action: "post-bar#choose keydown.enter->dialog#close:prevent",
      label: post_destination_action(destination, recipients_count),
      confirm: (post_release_confirm(recipients_count) if destination.mailed?),
      schedule_label: post_destination_schedule_action(destination, recipients_count),
      schedule_confirm: (post_schedule_confirm(recipients_count) if destination.mailed?),
      past_label: post_destination_past_action(destination, recipients_count),
      past_confirm: (post_release_past_confirm(recipients_count) if destination.name == "web_and_email")
    }
  end

  def post_send_action(recipients_count)
    t("posts_release_send_to", count: recipients_count, number: number_with_delimiter(recipients_count))
  end

  def post_release_confirm(recipients_count)
    t("posts_release_mail_confirm", count: recipients_count, number: number_with_delimiter(recipients_count))
  end

  def post_schedule_confirm(recipients_count)
    t("posts_schedule_mail_confirm", count: recipients_count, number: number_with_delimiter(recipients_count))
  end

  def post_release_past_confirm(recipients_count)
    t("posts_release_past_confirm", count: recipients_count, number: number_with_delimiter(recipients_count))
  end

  # Each hour names its zone, so nobody has to wonder whose nine o'clock it is.
  def post_release_hour_options(chosen)
    options_for_select(24.times.map { |hour| [ format("%02d:00 %s", hour, Time.zone.now.zone), hour ] }, chosen)
  end

  def post_web_html(post)
    post.html_on_the_web do |video|
      render partial: "public/posts/video", formats: :html, locals: { post: post, video: video }
    end
  end

  private
    def post_progress(post)
      if post.sent?
        post_sent_to(post)
      elsif post.published?
        t("posts_progress_not_sent_html", date: local_datetime_tag(post.published_at, style: :shortdate))
      elsif post.scheduled?
        t("posts_progress_for_html", schedule: post_schedule_description(post))
      else
        t("posts_progress_edited_html", time: local_datetime_tag(post.updated_at, style: :ago))
      end
    end

    def post_sent_to(post)
      count, unsent = post.deliveries_count, post_unsent(post.delivery_progress)
      sent, total = number_with_delimiter(post.delivery_progress[:sent]), number_with_delimiter(count)

      if post.sending?
        [ t("posts_progress_sending", count: count, sent: sent, total: total), *unsent ].join(", ")
      elsif unsent.empty?
        t("posts_progress_sent_to_html", count: post.delivery_progress[:sent], number: sent, date: post_sent_date(post))
      else
        safe_join [ t("posts_progress_sent_some_html", count: count, sent: sent, number: total, date: post_sent_date(post)), *unsent ], ", "
      end
    end

    def post_sent_date(post)
      local_datetime_tag post.sent_at, style: :shortdate
    end

    def post_unsent(progress)
      progress.slice(:refused, :unverified).reject { |_, count| count.zero? }
        .map { |state, count| t("posts_unsent_#{state}", count: count, number: number_with_delimiter(count)) }
    end

    def post_schedule_time(post)
      t "posts_schedule_time_html",
        date: local_datetime_tag(post.scheduled_posting_at, style: :date),
        time: local_datetime_tag(post.scheduled_posting_at, style: :time)
    end
end

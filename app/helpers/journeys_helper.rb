module JourneysHelper
  def journey_email_subject(email)
    email.subject.presence || t("untitled")
  end

  def journey_email_meta(email)
    safe_join [ (t("status_draft") if email.draft?), journey_email_timing(email).presence ].compact, " · "
  end

  def journey_email_timing(email)
    safe_join [ journey_email_wait(email), journey_email_hour(email) ].compact, " · "
  end

  # The hours of the zone the email's own was picked in, or of whoever is picking one now.
  def journey_email_hour_options(email)
    zone = journey_email_zone(email)

    options_for_select(24.times.map { |hour| [ format("%02d:00 %s", hour, zone.now.zone), hour ] }, email.send_hour)
  end

  def journey_email_wait(email)
    if email.delay_days.zero?
      t("journeys_timing_at_once")
    else
      t("journeys_timing_days_later", count: email.delay_days)
    end
  end

  # Stopped early is either way a run ends before its last email.
  def journey_run_counts(journey)
    safe_join [
      journey_run_count("in_progress", journey, %w[ in_progress ]),
      journey_run_count("finished", journey, %w[ finished ]),
      journey_run_count("stopped", journey, %w[ left refused ])
    ], " · "
  end

  # Drawn as a post's is, so the save's state is written over when it was last touched.
  def journey_email_bar_state(email)
    tag.span class: "post-actions__note post-actions__state txt-small txt-subtle" do
      safe_join [
        tag.span(email.draft? ? t("status_draft") : nil),
        tag.span(journey_email_edited(email), class: "post-actions__progress", role: "status", data: { save_state_target: "label" })
      ]
    end
  end

  private
    def journey_email_hour(email)
      if email.send_hour && email.journey.delayed?
        format("%02d:00 %s", email.send_hour, journey_email_zone(email).now.zone)
      end
    end

    def journey_email_zone(email)
      ActiveSupport::TimeZone[email.time_zone.to_s] || Time.zone
    end

    def journey_run_count(figure, journey, states)
      count = states.sum { |state| journey_run_counts_by_trigger_and_state.fetch([ journey.trigger, state ], 0) }

      t("journeys_runs_#{figure}", count: count, number: number_with_delimiter(count))
    end

    # Every journey on the page reads the one query.
    def journey_run_counts_by_trigger_and_state
      @journey_run_counts_by_trigger_and_state ||= Current.account.journey_runs.group(:trigger, :state).count
    end

    def journey_email_edited(email)
      t("journeys_edited_html", time: local_datetime_tag(email.updated_at, style: :ago))
    end
end

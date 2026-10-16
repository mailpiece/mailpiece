module NavigationHelper
  def navigation_home_path
    landing_path
  end

  def navigation_sections
    [
      (navigation_section(t("posts"), posts_path, "1", under: [ posts_path, journeys_path, snippets_path ]) if Current.user.admin?),
      (navigation_section(t("calendar_title"), calendar_path, "2") if Current.user.admin?),
      (navigation_section(t("subscribers"), subscribers_path, "3") if Current.user.admin?),
      (navigation_section(t("settings"), account_settings_path, "4", under: settings_paths + profile_paths) if Current.user.admin?),
      (navigation_section(t("profile"), user_path(Current.user), "5", under: profile_paths) unless Current.user.admin?)
    ].compact
  end

  def nav_link_to(section)
    link_to section[:path],
      class: "btn txt-small site-header__link",
      aria: { current: ("page" if section[:under].any? { request.path.start_with?(it) }), keyshortcuts: section[:hotkey] },
      data: { controller: "field-aware-hotkey", action: "keydown.#{section[:hotkey]}@document->field-aware-hotkey#click" } do
        safe_join [ section[:title], tag.kbd(section[:hotkey], class: "hide-on-touch", aria: { hidden: true }) ], " "
      end
  end

  private
    def navigation_section(title, path, hotkey, under: [ path ])
      { title: title, path: path, hotkey: hotkey, under: under }
    end

    def settings_paths
      [ account_settings_path, account_newsletter_path, account_handle_path, account_domain_path, account_sender_path, account_subscribe_form_path, account_welcome_path ]
    end

    # An admin reaches the profile from Settings. A member has no Settings, so it stays in the bar.
    def profile_paths
      [ users_path_prefix, account_join_code_path, my_passkeys_path, my_access_tokens_path, notifications_settings_path ]
    end

    def users_path_prefix
      "#{request.script_name}/users/"
    end
end

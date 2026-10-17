module SettingsHelper
  def settings_rows
    [
      { icon: "pencil", title: t("account_newsletter_title"), hint: Current.account.name, path: edit_account_newsletter_path },
      { icon: "globe", title: t("account_handle_title"), hint: settings_handle_hint, path: edit_account_handle_path },
      { icon: "world", title: t("account_domain_title"), hint: settings_domain_hint, path: edit_account_domain_path },
      { icon: "email", title: t("account_sender_title"), hint: settings_sending_hint, path: edit_account_sender_path },
      { icon: "share", title: t("account_outgoing_mail_title"), hint: settings_outgoing_mail_hint, path: account_outgoing_mail_path },
      { icon: "person-add", title: t("account_subscribe_form_title"), hint: t("account_subscribe_form_hint"), path: edit_account_subscribe_form_path },
      { icon: "home", title: t("account_welcome_title"), hint: settings_welcome_hint, path: account_welcome_path },
      { icon: "person", title: t("profile"), hint: Current.user.name, path: user_path(Current.user) }
    ]
  end

  def settings_path_to_finish_sending
    sender = Current.account.sender

    if sender.nil? || (sender.missing - %i[ transport ]).any?
      edit_account_sender_path
    else
      account_outgoing_mail_path
    end
  end

  private
    def settings_handle_hint
      if Current.account.handle
        root_url(script_name: Current.account.slug)
      else
        t("account_settings_address_pick_hint")
      end
    end

    def settings_domain_hint
      Current.account.domain || t("account_settings_domain_none_hint")
    end

    def settings_sending_hint
      if Current.account.sends_mail?
        Current.account.sender.from_address
      else
        t("account_settings_sender_not_set_up_hint")
      end
    end

    def settings_outgoing_mail_hint
      sender = Current.account.sender

      if sender&.relay?
        t("account_outgoing_mail_over_relay_hint", host: URI(sender.relay_url).host)
      elsif sender&.smtp?
        t("account_outgoing_mail_over_smtp_hint", host: sender.smtp_address)
      else
        t("account_settings_sender_not_set_up_hint")
      end
    end

    def settings_welcome_hint
      if Current.account.welcoming?
        t("account_welcome_on_hint")
      else
        t("account_welcome_off_hint")
      end
    end
end

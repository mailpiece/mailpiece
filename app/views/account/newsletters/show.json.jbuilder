json.(@account, :name)
json.description @account.description.to_plain_text
json.description_html @account.description.to_s
json.welcome_message @account.welcome_message.to_plain_text
json.welcome_message_html @account.welcome_message.to_s
json.locale @account.locale || I18n.default_locale.to_s
json.avatar_url account_avatar_url if @account.avatar.attached?

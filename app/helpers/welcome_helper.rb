module WelcomeHelper
  # Holds the account: on the app's own host several newsletters share one origin.
  def welcome_storage_key
    "welcome-#{Current.account.external_account_id}"
  end

  def welcome_data
    if Current.account.welcomes_visitors?
      { controller: "welcome", welcome_key_value: welcome_storage_key, action: "submit->welcome#remember" }
    end
  end
end

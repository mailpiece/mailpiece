class UserMailer < ApplicationMailer
  def email_change_confirmation(email_address:, token:, user:)
    @token = token
    @user = user
    mail to: email_address, subject: t("mailers_email_change_subject")
  end
end

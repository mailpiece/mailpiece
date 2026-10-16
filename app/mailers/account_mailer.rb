class AccountMailer < ApplicationMailer
  def cancellation(cancellation)
    @account = cancellation.account
    @user = cancellation.initiated_by

    mail(
      to: @user.identity.email_address,
      subject: t("mailers_account_cancelled_subject")
    )
  end
end

class MagicLinkMailer < ApplicationMailer
  helper SupportHelper

  def sign_in_instructions(magic_link)
    @magic_link = magic_link
    @identity = @magic_link.identity

    mail to: @identity.email_address, subject: t("mailers_sign_in_code_subject", code: @magic_link.code)
  end
end

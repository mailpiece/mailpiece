Rails.application.config.to_prepare do
  ActionMailer::MailDeliveryJob.include MailDeliveryErrorHandling
  ActionMailer::MailDeliveryJob.include SmtpDeliveryErrorHandling
end

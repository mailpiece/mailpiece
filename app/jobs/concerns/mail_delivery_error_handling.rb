# What a newsletter's transport raises. System mail fails with SMTP's own errors (SmtpDeliveryErrorHandling).
module MailDeliveryErrorHandling
  extend ActiveSupport::Concern

  included do
    # A confirmation sent twice beats one never sent. Over SMTP an issue's delivery keeps Unverified to itself and
    # is not retried; over the relay it is, under the same key.
    retry_on MailDelivery::Throttled, MailDelivery::Unavailable, MailDelivery::Unverified, wait: :polynomially_longer, attempts: 8

    discard_on MailDelivery::Refused do |_job, error|
      Rails.error.report(error, handled: true, severity: :info)
    end
  end
end

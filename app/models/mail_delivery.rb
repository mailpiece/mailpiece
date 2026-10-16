module MailDelivery
  IDEMPOTENCY_KEY_HEADER = "Idempotency-Key"
  TAGS_HEADER = "X-Tags"
  ISSUE_TAG = "issue"

  class Error < StandardError; end

  # Too many messages for now: the same message is welcome later.
  class Throttled < Error; end

  # The message never got a verdict: the server is down or unreachable.
  class Unavailable < Error; end

  # The sender's credentials were turned down. Retried like any outage, since the
  # same message goes out once they are fixed, but somebody has to be told.
  class Unauthorized < Unavailable; end

  # The message was handed over and no verdict came back: the server may or may not have taken it.
  # Over SMTP an issue's delivery is not retried on it, since with no idempotency key a retry may be a second copy.
  class Unverified < Error; end

  # The message itself was turned down, and sending it again changes nothing.
  class Refused < Error; end
end

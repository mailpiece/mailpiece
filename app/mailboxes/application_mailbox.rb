class ApplicationMailbox < ActionMailbox::Base
  routing all: :replies
end

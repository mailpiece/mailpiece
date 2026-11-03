module Account::RepliesReceivable
  extend ActiveSupport::Concern

  included do
    cattr_accessor :replies_domain
  end

  class_methods do
    def receiving_replies?
      replies_domain.present?
    end
  end
end

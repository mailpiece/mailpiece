module SubscriberImportScoped
  extend ActiveSupport::Concern

  private
    def imports
      Current.account.subscriber_imports.where(creator: Current.user)
    end
end

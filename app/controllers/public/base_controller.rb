class Public::BaseController < ApplicationController
  allow_unauthenticated_access

  before_action :set_public_cache_expiration
  before_action :ensure_account_accessible
  before_action :set_body_class

  skip_after_action :block_search_engine_indexing

  layout "public"

  private
    def set_public_cache_expiration
      if (request.get? || request.head?) && !authenticated?
        expires_in 30.seconds, public: true
      end
    end

    def ensure_account_accessible
      raise ActionController::RoutingError, "Not Found" if Current.account.cancelled?
    end

    def set_body_class
      @body_class = "newsletter"
    end
end

class SearchesController < ApplicationController
  include SearchRateLimiting

  before_action :ensure_admin

  limit_searches only: :show

  def show
    @query = params[:q].presence
    @posts = matching(Current.account.posts, account: Current.account).reverse_chronologically.preloaded.with_delivery_progress
    set_page_and_extract_portion_from matching(Current.account.subscribers).reverse_chronologically
  end

  private
    def searching?
      params[:q].present?
    end

    def matching(records, **scope)
      if @query
        records.matching(@query, **scope)
      else
        records.none
      end
    end
end

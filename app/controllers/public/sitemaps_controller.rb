class Public::SitemapsController < Public::BaseController
  def show
    @posts = Current.account.posts.published.listed.recently_published_first
  end
end

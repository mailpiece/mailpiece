class Public::PostsController < Public::BaseController
  before_action :redirect_signed_in_user, only: :index

  def index
    set_page_and_extract_portion_from Current.account.posts.published.listed.recently_published_first.with_rich_text_body.preload(:creator)
  end

  def show
    @post = Current.account.posts.published.on_the_web.find_by!(code: params[:id].last(Post::CODE_LENGTH))

    if params[:id] == @post.public_param
      headers["X-Robots-Tag"] = "noindex" unless @post.listed?

      respond_to do |format|
        format.html
        format.md { set_canonical_link }
      end
    else
      redirect_to current_address, status: :moved_permanently
    end
  end

  private
    def redirect_signed_in_user
      if request.format.html? && Current.user
        # Or a shared cache would hand the redirect to every visitor for 30 seconds.
        expires_now
        redirect_to landing_path
      end
    end

    # The Markdown is the same post a second time, so a search engine is pointed at the page.
    def set_canonical_link
      headers["Link"] = %(<#{public_post_url(@post.public_param, **Current.account.reader_url_options)}>; rel="canonical")
    end

    # An old slug is sent on in the format it was asked for.
    def current_address
      if request.format.md?
        public_post_markdown_path(@post.public_param)
      else
        public_post_path(@post.public_param)
      end
    end
end

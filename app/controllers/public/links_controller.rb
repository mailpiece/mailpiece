class Public::LinksController < Public::BaseController
  def show
    redirect_to Current.account.post_links.find_by!(code: params[:code]).url, allow_other_host: true
  end
end

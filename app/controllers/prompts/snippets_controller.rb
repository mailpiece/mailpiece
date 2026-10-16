class Prompts::SnippetsController < ApplicationController
  before_action :ensure_admin

  def index
    @audiences = Post::Audience.all
    @snippets = Current.account.snippets.alphabetically.with_rich_text_content

    render layout: false
  end
end

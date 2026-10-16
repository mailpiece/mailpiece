class SnippetsController < ApplicationController
  wrap_parameters :snippet, include: %i[ name content ]

  before_action :ensure_admin
  before_action :set_snippet, only: %i[ show edit update destroy ]

  def index
    set_page_and_extract_portion_from Current.account.snippets.alphabetically
  end

  def show
  end

  def new
    @snippet = Current.account.snippets.new
  end

  def create
    @snippet = Current.account.snippets.new(snippet_params)

    if @snippet.save
      respond_to do |format|
        format.html { redirect_to snippets_path, notice: t("snippets_saved") }
        format.json { render :show, status: :created, location: snippet_url(@snippet, format: :json) }
      end
    else
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @snippet.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit
  end

  def update
    if @snippet.update(snippet_params)
      respond_to do |format|
        format.html { redirect_to snippets_path, notice: t("snippets_saved") }
        format.json { render :show }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @snippet.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @snippet.destroy!

    respond_to do |format|
      format.html { redirect_to snippets_path, notice: t("snippets_deleted", name: @snippet.name) }
      format.json { head :no_content }
    end
  end

  private
    def set_snippet
      @snippet = Current.account.snippets.find(params[:id])
    end

    def snippet_params
      params.expect(snippet: [ :name, :content ])
    end
end

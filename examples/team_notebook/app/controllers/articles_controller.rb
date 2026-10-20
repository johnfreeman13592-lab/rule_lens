class ArticlesController < ApplicationController
  before_action :set_article, only: [:show, :edit, :update, :destroy]
  after_action :verify_policy_scoped, only: :index
  after_action :verify_authorized, except: :index

  def index
    @articles = policy_scope(Article).includes(:author).order(:slug)
  end

  def show
    authorize @article
  end

  def new
    @article = current_team.articles.build(author: current_user)
    authorize @article, :create?
  end

  def create
    @article = current_team.articles.build(article_params.merge(author: current_user))
    authorize @article
    if @article.save
      redirect_to [current_team, @article], status: :see_other, notice: "記事を作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @article, :update?
  end

  def update
    authorize @article
    if @article.update(article_params)
      redirect_to [current_team, @article], status: :see_other, notice: "記事を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @article
    @article.destroy!
    redirect_to team_articles_path(current_team), status: :see_other, notice: "記事を削除しました。"
  end

  private

  def set_article
    @article = current_team.articles.find(params[:id])
  end

  def article_params = params.require(:article).permit(:title, :body, :published)
end

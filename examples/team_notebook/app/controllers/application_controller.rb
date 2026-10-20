class ApplicationController < ActionController::Base
  include Pundit::Authorization
  helper_method :current_user, :current_team, :role_label
  rescue_from ActiveRecord::RecordNotFound, Pundit::NotAuthorizedError do
    head :not_found
  end

  private

  def current_user
    @current_user ||= User.find_by!(slug: session[:actor_slug] || "aoi")
  end

  def current_team
    @current_team ||= current_user.teams.find(params[:team_id])
  end

  def pundit_user = AuthorizationContext.new(current_user, current_team)

  def role_label(role)
    { "admin" => "管理者", "editor" => "編集者", "member" => "一般メンバー" }.fetch(role)
  end
end

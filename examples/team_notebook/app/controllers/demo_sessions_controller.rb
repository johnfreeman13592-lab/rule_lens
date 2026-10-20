class DemoSessionsController < ApplicationController
  def create
    actor = User.find_by!(slug: params[:actor_slug])
    reset_session
    session[:actor_slug] = actor.slug
    redirect_to root_path, status: :see_other, notice: "#{actor.name}に切り替えました。"
  end
end

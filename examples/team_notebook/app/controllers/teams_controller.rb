class TeamsController < ApplicationController
  def index
    @teams = current_user.teams.order(:slug)
  end
end

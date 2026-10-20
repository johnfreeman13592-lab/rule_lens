AuthorizationContext = Data.define(:user, :team) do
  def membership = user.memberships.find_by(team: team)
  def member? = !membership.nil?
  def admin? = membership&.role == "admin"

  # Trial guide: edit only this method to compare the three code revisions.
  def editor_can_manage? = false

  def manage_articles? = admin? || editor_can_manage?
end

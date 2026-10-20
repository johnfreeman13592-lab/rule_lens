class ArticlePolicy
  def initialize(context, record)
    @context, @record = context, record
  end

  def create? = same_team? && @context.member?
  def show? = same_team? && @context.member? && (@record.published? || update?)
  def update? = same_team? && @context.member? && (@context.manage_articles? || owner?)
  def destroy? = same_team? && @context.member? && (@context.admin? || owner?)

  class Scope
    def initialize(context, scope)
      @context, @scope = context, scope
    end

    def resolve
      return @scope.none unless @context.member?
      selected = @scope.where(team: @context.team)
      return selected if @context.manage_articles?

      selected.where(published: true).or(selected.where(author: @context.user))
    end
  end

  private

  def same_team? = @record.team_id == @context.team.id
  def owner? = @record.author_id == @context.user.id
end

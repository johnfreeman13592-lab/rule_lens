class ArticlePolicy
  class Scope
    def initialize(user, scope)
      @user, @scope = user, scope
    end

    def resolve
      @scope.where(published: true).or(@scope.where(author_id: @user.id))
    end
  end

  def initialize(user, record)
    @user, @record = user, record
  end

  def show? = true
  def update? = !@user.nil? && @user.id == @record.author_id
end

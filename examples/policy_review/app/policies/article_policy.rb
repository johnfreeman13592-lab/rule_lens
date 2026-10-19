class ArticlePolicy
  def initialize(user, record)
    @user, @record = user, record
  end

  def show? = true
  def update? = !@user.nil? && @user.id == @record.author_id
end

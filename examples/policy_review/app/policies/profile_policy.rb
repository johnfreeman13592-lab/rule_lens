class ProfilePolicy
  def initialize(user, record)
    @user, @record = user, record
  end

  def update? = !@user.nil? && @user.id == @record.id
end

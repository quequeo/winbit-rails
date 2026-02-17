class AdminSessionSerializer
  def initialize(user)
    @user = user
  end

  def as_json(*)
    {
      email: user.email,
      superadmin: user.superadmin?
    }
  end

  private

  attr_reader :user
end

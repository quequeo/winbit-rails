class AdminUserSerializer
  def initialize(admin)
    @admin = admin
  end

  def as_json(*)
    {
      id: admin.id,
      name: admin.name,
      email: admin.email,
      role: admin.role,
      notify_deposit_created: admin.notify_deposit_created,
      notify_withdrawal_created: admin.notify_withdrawal_created,
      created_at: admin.created_at
    }
  end

  private

  attr_reader :admin
end

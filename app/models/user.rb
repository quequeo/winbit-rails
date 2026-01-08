class User < ApplicationRecord
  ROLES = %w[ADMIN SUPERADMIN].freeze

  devise :database_authenticatable,
         :omniauthable,
         omniauth_providers: [:google_oauth2]

  validates :email, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: ROLES }

  # OmniAuth-only: we don't require passwords.
  def password_required?
    false
  end

  def admin?
    role == 'ADMIN'
  end

  def superadmin?
    role == 'SUPERADMIN'
  end

  def self.from_google_omniauth(auth)
    email = auth.info.email.to_s

    # Only allow emails already whitelisted as admins
    user = find_by(email: email)
    return nil unless user

    user.update!(provider: auth.provider, uid: auth.uid)
    user
  end
end

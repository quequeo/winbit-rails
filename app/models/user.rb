class User < ApplicationRecord
  ROLES = %w[ADMIN SUPERADMIN].freeze

  has_many :applied_trading_fees, class_name: 'TradingFee', foreign_key: 'applied_by_id', dependent: :restrict_with_error

  devise :database_authenticatable,
         :omniauthable,
         omniauth_providers: [:google_oauth2]

  validates :email, presence: true, uniqueness: true
  validates :role, presence: true, inclusion: { in: ROLES }

  # Scopes for notification preferences
  scope :notify_deposits, -> { where(notify_deposit_created: true) }
  scope :notify_withdrawals, -> { where(notify_withdrawal_created: true) }

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
    return nil unless auth.present?

    email =
      if auth.respond_to?(:dig)
        auth.dig('info', 'email').to_s
      elsif auth.respond_to?(:info)
        auth.info&.email.to_s
      else
        ''
      end

    return nil if email.blank?

    # Only allow emails already whitelisted as admins
    user = find_by(email: email)
    return nil unless user

    provider = auth.respond_to?(:provider) ? auth.provider : (auth['provider'] rescue nil)
    uid = auth.respond_to?(:uid) ? auth.uid : (auth['uid'] rescue nil)
    user.update!(provider: provider, uid: uid)
    user
  end
end

class Wallet < ApplicationRecord
  ASSETS = %w[USDT USDC].freeze
  NETWORKS = %w[TRC20 BEP20 ERC20 POLYGON].freeze

  validates :asset, presence: true, inclusion: { in: ASSETS }
  validates :network, presence: true, inclusion: { in: NETWORKS }
  validates :address, presence: true

  validates :asset, uniqueness: { scope: :network }
end

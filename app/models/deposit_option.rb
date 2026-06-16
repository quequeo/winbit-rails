class DepositOption < ApplicationRecord
  CATEGORIES = %w[CASH_ARS CASH_USD BANK_ARS LEMON CRYPTO SWIFT CUSTOM].freeze
  CURRENCIES = %w[ARS USD USDT USDC].freeze

  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :label, presence: true
  validates :currency, presence: true, inclusion: { in: CURRENCIES }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :validate_details_for_category

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :category, :label) }

  private

  def validate_details_for_category
    return if category.blank?

    case category
    when "BANK_ARS"
      validate_required_detail_keys("bank_name", "holder", "cbu_cvu")
    when "LEMON"
      validate_required_detail_keys("lemon_tag")
    when "CRYPTO"
      validate_required_detail_keys("address", "network")
    when "SWIFT"
      validate_required_detail_keys("bank_name", "holder", "swift_code", "account_number")
    when "CUSTOM"
      validate_custom_fields
    end
  end

  def validate_custom_fields
    fields = details["fields"]
    unless fields.is_a?(Array) && fields.any?
      errors.add(:details, "must include at least one field for CUSTOM")
      return
    end

    fields.each_with_index do |field, index|
      unless field.is_a?(Hash) && field["label"].present? && field["value"].present?
        errors.add(:details, "field #{index + 1} must have label and value")
      end
    end
  end

  def validate_required_detail_keys(*keys)
    keys.each do |key|
      if details[key].blank?
        errors.add(:details, "must include '#{key}' for #{category}")
      end
    end
  end
end

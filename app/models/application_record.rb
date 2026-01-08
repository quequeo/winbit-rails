class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  before_create :assign_string_primary_key

  private

  def assign_string_primary_key
    return unless self.class.primary_key == 'id'
    return unless has_attribute?(:id)
    return unless self.class.type_for_attribute('id')&.type == :string
    return if id.present?

    self.id = SecureRandom.uuid
  end
end

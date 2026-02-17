module DateParamParsing
  extend ActiveSupport::Concern

  private

  def parse_date_param(value)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end

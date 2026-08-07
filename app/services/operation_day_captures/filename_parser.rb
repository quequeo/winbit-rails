module OperationDayCaptures
  class FilenameParser
    ASSET_ALIASES = {
      'NQ' => 'MNQ',
      'BTC' => 'MBT',
      'MES' => 'MES',
      'MYM' => 'MYM',
      'MNQ' => 'MNQ',
      'MBT' => 'MBT',
    }.freeze

    FILENAME_PATTERN = /\A(?<asset>[A-Za-z]+)_{1}(?<day>\d{2})\.(?<month>\d{2})\.(?<year>\d{2,4})_(?<result>.+)\.png\z/i

    Result = Struct.new(
      :ok,
      :skip_reason,
      :asset,
      :capture_date,
      :filename_result,
      :result_label,
      keyword_init: true,
    )

    def self.parse(filename)
      new(filename).parse
    end

    def initialize(filename)
      @filename = File.basename(filename.to_s)
    end

    def parse
      match = FILENAME_PATTERN.match(@filename)
      return failure('unparseable_filename') unless match

      result_token = match[:result].to_s.strip
      return failure('simulada') if simulada?(result_token)

      asset = ASSET_ALIASES[match[:asset].to_s.upcase]
      return failure('alias_fail') if asset.blank?

      capture_date = parse_date(match[:day], match[:month], match[:year])
      return failure('invalid_date') unless capture_date

      Result.new(
        ok: true,
        skip_reason: nil,
        asset: asset,
        capture_date: capture_date,
        filename_result: result_token,
        result_label: nil,
      )
    end

    private

    def failure(reason)
      Result.new(ok: false, skip_reason: reason)
    end

    def simulada?(token)
      token.upcase.include?('SIMULADA')
    end

    def parse_date(day, month, year)
      yyyy = year.length == 2 ? "20#{year}" : year
      Date.new(yyyy.to_i, month.to_i, day.to_i)
    rescue ArgumentError, Date::Error
      nil
    end
  end
end

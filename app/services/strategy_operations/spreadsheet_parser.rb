module StrategyOperations
  class SpreadsheetParser
    HEADER_ASSET = 'ACTIVO'
    SHEET_NAME = '2026'
    YEAR = 2026

    ParsedRow = Struct.new(
      :asset,
      :timeframe,
      :month_label,
      :operation_date,
      :opened_at,
      :closed_at,
      :result_label,
      :result_usd,
      :ratio,
      :direction,
      :notes,
      keyword_init: true,
    )

    def initialize(path:)
      @path = path
    end

    def rows
      sheet = open_sheet
      header_row = find_header_row(sheet)
      return [] unless header_row

      first_data_row = header_row + 1
      (first_data_row..sheet.last_row).filter_map do |row_number|
        parse_row(sheet, row_number)
      end
    end

    private

    attr_reader :path

    def open_sheet
      book = Roo::Spreadsheet.open(path)
      book.sheet(SHEET_NAME)
    rescue RangeError
      Roo::Spreadsheet.open(path).sheet(0)
    end

    def find_header_row(sheet)
      (1..[sheet.last_row, 20].min).find do |row_number|
        cell_value(sheet, row_number, 1).to_s.strip.upcase == HEADER_ASSET
      end
    end

    def parse_row(sheet, row_number)
      asset = cell_value(sheet, row_number, 1).to_s.strip
      return nil if asset.blank?

      date_text = cell_value(sheet, row_number, 4).to_s.strip
      operation_date = parse_operation_date(date_text)
      return nil unless operation_date

      ParsedRow.new(
        asset: asset,
        timeframe: cell_value(sheet, row_number, 2).to_s.strip.presence,
        month_label: cell_value(sheet, row_number, 3).to_s.strip.presence,
        operation_date: operation_date,
        opened_at: cell_value(sheet, row_number, 6).to_s.strip.presence,
        closed_at: cell_value(sheet, row_number, 7).to_s.strip.presence,
        result_label: cell_value(sheet, row_number, 8).to_s.strip.presence,
        result_usd: parse_decimal(cell_value(sheet, row_number, 9)),
        ratio: parse_decimal(cell_value(sheet, row_number, 10)),
        direction: cell_value(sheet, row_number, 13).to_s.strip.presence,
        notes: cell_value(sheet, row_number, 14).to_s.strip.presence,
      )
    end

    def cell_value(sheet, row_number, column_number)
      sheet.cell(row_number, column_number)
    rescue StandardError
      nil
    end

    def parse_operation_date(text)
      return nil if text.blank?

      if text.match?(%r{\A\d{1,2}/\d{1,2}\z})
        day, month = text.split('/').map(&:to_i)
        Date.new(YEAR, month, day)
      else
        Date.parse(text)
      end
    rescue ArgumentError, Date::Error
      nil
    end

    def parse_decimal(value)
      return nil if value.nil?

      text = value.to_s.strip
      return nil if text.blank?

      BigDecimal(text.tr(',', '.'))
    rescue ArgumentError
      nil
    end
  end
end

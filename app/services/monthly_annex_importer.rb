# frozen_string_literal: true

require 'json'

class MonthlyAnnexImporter
  DEFAULT_JSON_PATH = Rails.root.join('db/seeds/monthly_annex_rows.json').freeze

  attr_reader :errors, :imported_count, :skipped_count

  def initialize(json_path: DEFAULT_JSON_PATH)
    @json_path = json_path
    @errors = []
    @imported_count = 0
    @skipped_count = 0
  end

  def import!
    rows = JSON.parse(File.read(@json_path))
    investors_by_name = Investor.all.index_by { |inv| normalize_name(inv.name) }

    rows.each do |row|
      next if row['ytd_total']

      investor = find_investor(row['investor_name'], investors_by_name)
      unless investor
        @errors << "Inversor no encontrado: #{row['investor_name']}"
        @skipped_count += 1
        next
      end

      month = if row['month'] == 'INGRESO'
                Date.new(2026, 4, 1)
      else
                Date.strptime("#{row['month']}-01", '%Y-%m-%d')
      end

      record = InvestorMonthlyAnnexRow.find_or_initialize_by(investor: investor, month: month)
      record.assign_attributes(
        return_percent: row['return_percent'],
        return_usd: row['return_usd'],
        deposits: row['deposits'] || 0,
        withdrawals: row['withdrawals'] || 0,
        service_cost: row['service_cost'] || 0,
        portfolio_value: row['portfolio_value'],
        opening_snapshot: row['opening_snapshot'] == true,
        entry_row: row['entry_row'] == true,
        source: 'spreadsheet',
      )
      record.save!
      @imported_count += 1
    end

    @errors.empty?
  end

  private

  NAME_ALIASES = {
    'luis m. crocci' => 'luis matias crocci',
    'dario vazquez' => 'dario agustin vazquez',
    'federico boero' => 'federico martin boero',
    'jaime garcia mendez' => 'jaime garcia',
  }.freeze

  EMAIL_BY_SPREADSHEET = {
    'jaime garcia mendez' => 'jaimegarciamendez@gmail.com',
  }.freeze

  def find_investor(spreadsheet_name, investors_by_name)
    key = normalize_name(spreadsheet_name)
    if EMAIL_BY_SPREADSHEET[key]
      return Investor.find_by(email: EMAIL_BY_SPREADSHEET[key])
    end

    investors_by_name[key] || investors_by_name[NAME_ALIASES[key]]
  end

  def normalize_name(name)
    I18n.transliterate(name.to_s).downcase.gsub(/\s+/, ' ').strip
  end
end

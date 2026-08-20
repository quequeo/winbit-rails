# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  class NameMatcher
    Result = Struct.new(:investor, :reason, keyword_init: true)

    def initialize(investors = Investor.all)
      @by_key = investors.group_by { |investor| normalize(investor.name) }
    end

    def find(name)
      key = normalize(name)
      return Result.new(reason: 'investor_not_found') if key.blank?

      matches = @by_key[key] || []
      return Result.new(reason: 'investor_not_found') if matches.empty?
      return Result.new(reason: 'ambiguous_name') if matches.size > 1

      Result.new(investor: matches.first)
    end

    def self.normalize(name)
      ActiveSupport::Inflector.transliterate(Month.utf8(name))
        .downcase
        .gsub(/[^a-z0-9]+/, ' ')
        .squish
    end

    private

    def normalize(name)
      self.class.normalize(name)
    end
  end
end

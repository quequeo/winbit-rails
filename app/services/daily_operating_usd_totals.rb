class DailyOperatingUsdTotals
  OPERATING_CLOSE_HOUR = 17

  class << self
    def for_dates(dates)
      dates = Array(dates).map(&:to_date).uniq
      return {} if dates.empty?

      timestamps = dates.index_with { |day| movement_time(day) }
      rows = PortfolioHistory
             .where(status: 'COMPLETED', event: 'OPERATING_RESULT', date: timestamps.values)
             .group(:date)
             .sum(:amount)

      timestamps.each_with_object({}) do |(day, at_time), totals|
        totals[day] = rows.fetch(at_time, 0).to_f.round(2)
      end
    end

    def for_date(day)
      for_dates([day])[day.to_date] || 0.0
    end

    def movement_time(day)
      day = day.to_date
      Time.zone.local(day.year, day.month, day.day, OPERATING_CLOSE_HOUR, 0, 0)
    end
  end
end

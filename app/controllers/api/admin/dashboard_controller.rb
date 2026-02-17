module Api
  module Admin
    class DashboardController < BaseController
      def show
        active_investor_ids = Investor.where(status: 'ACTIVE').pluck(:id)
        investor_count = active_investor_ids.size
        pending_request_count = InvestorRequest.where(status: 'PENDING', investor_id: active_investor_ids).count
        total_aum = Portfolio.where(investor_id: active_investor_ids).sum(:current_balance)

        end_date = Date.current
        now = Time.current

        # Strategy return (TWR) - YTD and All-time (since first record)
        ytd_from = Time.zone.local(end_date.year, 1, 1, 0, 0, 0)
        all_from = PortfolioHistory.where(status: 'COMPLETED').minimum(:date)

        ytd_return = TimeWeightedReturnCalculator.for_platform(from: ytd_from, to: now)
        all_return = TimeWeightedReturnCalculator.for_platform(from: all_from, to: now)

        days_param = params[:days].to_s.strip

        # days=0 => "Todo desde el inicio" (desde el primer movimiento), con un cap de seguridad.
        if days_param == '0'
          earliest = PortfolioHistory.where(status: 'COMPLETED').minimum(:date)&.to_date
          start_date = earliest || (end_date - 89)

          max_days = 3650
          if ((end_date - start_date).to_i + 1) > max_days
            start_date = end_date - (max_days - 1)
          end
        else
          days = params[:days].to_i
          days = 90 if days <= 0
          days = 7 if days < 7
          days = 365 if days > 365

          start_date = end_date - (days - 1)
        end

        render json: {
          data: AdminDashboardSerializer.new(
            investor_count: investor_count,
            pending_request_count: pending_request_count,
            total_aum: total_aum,
            aum_series: aum_series(start_date: start_date, end_date: end_date),
            strategy_return_ytd_usd: ytd_return.pnl_usd,
            strategy_return_ytd_percent: ytd_return.twr_percent,
            strategy_return_all_usd: all_return.pnl_usd,
            strategy_return_all_percent: all_return.twr_percent
          ).as_json
        }
      end

      private

      # Returns daily total AUM snapshots for the given date range (inclusive).
      # If there is no PortfolioHistory yet, fall back to a flat series based on current Portfolio balances.
      def aum_series(start_date:, end_date:)
        start_date = start_date.to_date
        end_date = end_date.to_date

        active_ids = Investor.where(status: 'ACTIVE').pluck(:id)

        # If we don't have any movements yet, show a flat line.
        unless PortfolioHistory.where(status: 'COMPLETED', investor_id: active_ids).exists?
          current = Portfolio.where(investor_id: active_ids).sum(:current_balance).to_f
          return (start_date..end_date).map { |d| { date: d.strftime('%Y-%m-%d'), totalAum: current } }
        end

        investor_ids = active_ids

        range_start_time = Time.zone.local(start_date.year, start_date.month, start_date.day, 0, 0, 0)
        range_end_time = Time.zone.local(end_date.year, end_date.month, end_date.day, 23, 59, 59)

        balances = {}
        total = 0.0

        # Initialize balances at range start from the last known balance before the range.
        initial_rows = PortfolioHistory
                       .where(status: 'COMPLETED', investor_id: investor_ids)
                       .where('date < ?', range_start_time)
                       .select('DISTINCT ON (investor_id) investor_id, new_balance')
                       .order('investor_id, date DESC, created_at DESC')

        initial_rows.each do |r|
          b = r.new_balance.to_f
          balances[r.investor_id] = b
          total += b
        end

        histories = PortfolioHistory
                    .where(status: 'COMPLETED', investor_id: investor_ids)
                    .where(date: range_start_time..range_end_time)
                    .order(:date, :created_at)

        series = []
        day = start_date

        histories.each do |h|
          h_day = h.date.to_date
          while day < h_day
            series << { date: day.strftime('%Y-%m-%d'), totalAum: total.round(2) }
            day += 1.day
          end

          old = balances[h.investor_id] || 0.0
          newb = h.new_balance.to_f
          balances[h.investor_id] = newb
          total += (newb - old)
        end

        while day <= end_date
          series << { date: day.strftime('%Y-%m-%d'), totalAum: total.round(2) }
          day += 1.day
        end

        series
      end
    end
  end
end

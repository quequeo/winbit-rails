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

        ytd_from = Time.zone.local(end_date.year, 1, 1, 0, 0, 0)
        all_from = PortfolioHistory.where(status: 'COMPLETED', investor_id: active_investor_ids).minimum(:date)

        ytd_return = TimeWeightedReturnCalculator.for_platform(from: ytd_from, to: now, investor_ids: active_investor_ids)
        all_return = TimeWeightedReturnCalculator.for_platform(from: all_from, to: now, investor_ids: active_investor_ids)

        days_param = params[:days].to_s.strip

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

        operating_month = operating_month_summary
        net_flows = net_flows_for_period(start_date: start_date, end_date: end_date, investor_ids: active_investor_ids)

        render json: {
          data: AdminDashboardSerializer.new(
            investor_count: investor_count,
            pending_request_count: pending_request_count,
            total_aum: total_aum,
            aum_series: aum_series(start_date: start_date, end_date: end_date),
            strategy_return_ytd_usd: ytd_return.pnl_usd,
            strategy_return_ytd_percent: ytd_return.twr_percent,
            strategy_return_all_usd: all_return.pnl_usd,
            strategy_return_all_percent: all_return.twr_percent,
            operating_return_month_usd: operating_month[:total_usd],
            operating_return_month_percent: operating_month[:compounded_percent],
            net_deposits_usd: net_flows[:deposits_usd],
            net_withdrawals_usd: net_flows[:withdrawals_usd],
            net_flows_usd: net_flows[:net_usd],
            alerts: build_alerts(active_investor_ids: active_investor_ids, pending_request_count: pending_request_count),
            aum_concentration: aum_concentration(active_investor_ids: active_investor_ids, total_aum: total_aum),
          ).as_json
        }
      end

      private

      def operating_month_summary
        month_start = Date.current.beginning_of_month
        month_end = Date.current
        results = DailyOperatingResult.where(date: month_start..month_end).order(:date)
        usd_by_date = DailyOperatingUsdTotals.for_dates(results.map(&:date))

        factor = results.reduce(BigDecimal('1')) do |acc, result|
          acc * (BigDecimal('1') + (BigDecimal(result.percent.to_s) / 100))
        end
        compounded = results.empty? ? 0.0 : ((factor - 1) * 100).round(2, :half_up).to_f
        total_usd = results.sum { |result| usd_by_date[result.date] || 0.0 }.round(2)

        { compounded_percent: compounded, total_usd: total_usd }
      end

      def net_flows_for_period(start_date:, end_date:, investor_ids:)
        range_start_time = Time.zone.local(start_date.year, start_date.month, start_date.day, 0, 0, 0)
        range_end_time = Time.zone.local(end_date.year, end_date.month, end_date.day, 23, 59, 59)

        scope = PortfolioHistory.where(status: 'COMPLETED', investor_id: investor_ids, date: range_start_time..range_end_time)
        deposits = scope.where(event: 'DEPOSIT').sum(:amount).to_f.round(2)
        withdrawals = scope.where(event: 'WITHDRAWAL').sum(:amount).to_f.round(2)

        {
          deposits_usd: deposits,
          withdrawals_usd: withdrawals,
          net_usd: (deposits - withdrawals).round(2),
        }
      end

      def build_alerts(active_investor_ids:, pending_request_count:)
        alerts = []

        if pending_request_count.positive?
          oldest = InvestorRequest.where(status: 'PENDING', investor_id: active_investor_ids).minimum(:requested_at)
          if oldest.present? && oldest < 2.days.ago
            alerts << {
              type: 'pending_requests_stale',
              severity: 'warning',
              message: "#{pending_request_count} solicitudes pendientes, la más antigua desde #{oldest.in_time_zone.strftime('%d/%m/%Y')}",
            }
          else
            alerts << {
              type: 'pending_requests',
              severity: 'info',
              message: "#{pending_request_count} solicitud#{'es' if pending_request_count != 1} pendiente#{'s' if pending_request_count != 1} de revisión",
            }
          end
        end

        unless DailyOperatingResult.exists?(date: Date.current)
          alerts << {
            type: 'operating_missing_today',
            severity: 'warning',
            message: 'Todavía no se cargó la operativa diaria de hoy',
          }
        end

        alerts
      end

      def aum_concentration(active_investor_ids:, total_aum:, limit: 5)
        total = total_aum.to_f
        return [] if total <= 0

        Portfolio.where(investor_id: active_investor_ids)
                 .includes(:investor)
                 .order(current_balance: :desc)
                 .limit(limit)
                 .map do |portfolio|
          balance = portfolio.current_balance.to_f
          {
            investorId: portfolio.investor_id,
            name: portfolio.investor&.name,
            email: portfolio.investor&.email,
            balance: balance.round(2),
            sharePercent: ((balance / total) * 100).round(2),
          }
        end
      end

      def aum_series(start_date:, end_date:)
        start_date = start_date.to_date
        end_date = end_date.to_date

        active_ids = Investor.where(status: 'ACTIVE').pluck(:id)

        unless PortfolioHistory.where(status: 'COMPLETED', investor_id: active_ids).exists?
          current = Portfolio.where(investor_id: active_ids).sum(:current_balance).to_f
          return (start_date..end_date).map { |d| { date: d.strftime('%Y-%m-%d'), totalAum: current } }
        end

        investor_ids = active_ids

        range_start_time = Time.zone.local(start_date.year, start_date.month, start_date.day, 0, 0, 0)
        range_end_time = Time.zone.local(end_date.year, end_date.month, end_date.day, 23, 59, 59)

        balances = {}
        total = 0.0

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

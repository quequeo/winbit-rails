module Api
  module Admin
    class DailyOperatingResultsController < BaseController
      before_action :require_superadmin!, only: [:create, :update]

      def index
        scope = DailyOperatingResult.includes(:applied_by).order(date: :desc)
        paginated_result = paginate(scope, default_per_page: 10, max_per_page: 50)
        results = paginated_result[:records]
        usd_by_date = DailyOperatingUsdTotals.for_dates(results.map(&:date))

        render json: {
          data: results.map { |r| DailyOperatingResultSerializer.new(r, amount_usd: usd_by_date[r.date]).as_json },
          meta: paginated_result[:pagination]
        }
      end

      def series
        months = params[:months].to_i
        months = 3 if months <= 0
        months = 24 if months > 24

        offset = params[:offset].to_i
        offset = 0 if offset < 0

        end_month = Date.current.beginning_of_month - offset.months
        start_month = end_month - (months - 1).months
        start_date = start_month
        end_date = end_month.end_of_month

        results = DailyOperatingResult.where(date: start_date..end_date).order(:date)
        usd_by_date = DailyOperatingUsdTotals.for_dates(results.map(&:date))

        render json: {
          data: results.map do |result|
            {
              date: result.date.strftime('%Y-%m-%d'),
              percent: result.percent.to_f,
              amount_usd: usd_by_date[result.date] || 0.0,
              notes: result.notes,
            }
          end,
        }
      end

      def monthly_summary
        months = params[:months].to_i
        months = 12 if months <= 0
        months = 24 if months > 24

        offset = params[:offset].to_i
        offset = 0 if offset < 0

        end_month   = Date.current.beginning_of_month - offset.months
        start_month = end_month - (months - 1).months

        results = DailyOperatingResult.where(date: start_month..end_month.end_of_month).order(date: :desc)
        grouped = results.group_by { |r| r.date.beginning_of_month }
        usd_by_date = DailyOperatingUsdTotals.for_dates(results.map(&:date))

        months_list = []
        cur = start_month
        while cur <= end_month
          months_list << cur
          cur = (cur >> 1)
        end

        data = months_list.reverse.map do |month_start|
          rs = grouped[month_start] || []

          factor = rs.reduce(BigDecimal('1')) do |acc, r|
            acc * (BigDecimal('1') + (BigDecimal(r.percent.to_s) / 100))
          end
          compounded = ((factor - 1) * 100).round(2, :half_up)
          total_usd = rs.sum { |r| usd_by_date[r.date] || 0.0 }.round(2)

          {
            month: month_start.strftime('%Y-%m'),
            days: rs.size,
            compounded_percent: compounded.to_f,
            total_usd: total_usd,
            first_date: rs.map(&:date).min,
            last_date: rs.map(&:date).max
          }
        end

        render json: { data: data }
      end

      def by_month
        month = params[:month].to_s.strip
        unless month.match?(/^\d{4}-\d{2}$/)
          render_error('Mes inválido. Usar formato YYYY-MM', status: :unprocessable_content)
          return
        end

        start_date = Date.strptime("#{month}-01", '%Y-%m-%d')
        end_date = start_date.end_of_month

        results = DailyOperatingResult.where(date: start_date..end_date).order(date: :desc)
        usd_by_date = DailyOperatingUsdTotals.for_dates(results.map(&:date))

        render json: {
          data: results.map { |r| DailyOperatingResultByMonthItemSerializer.new(r, amount_usd: usd_by_date[r.date]).as_json }
        }
      rescue ArgumentError
        render_error('Mes inválido. Usar formato YYYY-MM', status: :unprocessable_content)
      end


      def preview
        date = parse_date_param(params[:date])

        applicator = DailyOperatingResultApplicator.new(
          date: date,
          percent: params[:percent],
          amount_usd: params[:amount_usd],
          applied_by: current_user,
          notes: params[:notes]
        )

        data = applicator.preview
        if data.nil?
          render_error(applicator.errors.join(', '), status: :unprocessable_content)
          return
        end

        render json: { data: data }
      end

      def create
        date = parse_date_param(params[:date])

        applicator = DailyOperatingResultApplicator.new(
          date: date,
          percent: params[:percent],
          amount_usd: params[:amount_usd],
          applied_by: current_user,
          notes: params[:notes]
        )

        if applicator.apply
          result = DailyOperatingResult.find_by!(date: date)
          upsert = StrategyOperations::UpsertForDate.new(
            date: date,
            created_by: current_user,
            params: strategy_operation_params,
            result_usd: DailyOperatingUsdTotals.for_date(date),
          )
          unless upsert.call
            render_error(upsert.error || 'No se pudo guardar el detalle de la operación', status: :unprocessable_content)
            return
          end

          ActivityLogger.log(
            user: current_user,
            action: 'apply_daily_operating_result',
            target: result,
            metadata: {
              date: date.to_s,
              percent: result.percent.to_f,
              amount_usd: params[:amount_usd].presence&.to_f,
            }
          )
          render json: { data: DailyOperatingResultSerializer.new(result).as_json }, status: :created
        else
          status = applicator.errors.any? { |e| e.include?('Ya existe') } ? :conflict : :unprocessable_content
          render_error(applicator.errors.join(', '), status: status)
        end
      end

      def edit_preview
        result = DailyOperatingResult.find(params[:id])
        new_percent = params[:percent]

        editor = DailyOperatingResultEditor.new(
          result: result,
          new_percent: new_percent,
          edited_by: current_user
        )

        data = editor.preview
        if data.nil?
          render_error(editor.errors.join(', '), status: :unprocessable_content)
          return
        end

        render json: { data: data }
      end

      def update
        result = DailyOperatingResult.find(params[:id])

        editor = DailyOperatingResultEditor.new(
          result: result,
          new_percent: params[:percent],
          edited_by: current_user,
          notes: params.key?(:notes) ? params[:notes] : nil
        )

        if editor.apply
          upsert = StrategyOperations::UpsertForDate.new(
            date: result.date,
            created_by: current_user,
            params: strategy_operation_params,
            result_usd: DailyOperatingUsdTotals.for_date(result.date),
          )
          unless upsert.call
            render_error(upsert.error || 'No se pudo guardar el detalle de la operación', status: :unprocessable_content)
            return
          end

          render json: { data: DailyOperatingResultSerializer.new(result.reload).as_json }
        else
          render_error(editor.errors.join(', '), status: :unprocessable_content)
        end
      end

      private

      def strategy_operation_params
        raw = params[:strategy_operation]
        return nil if raw.blank?

        raw.permit(
          :asset,
          :timeframe,
          :direction,
          :result_label,
          :ratio,
          :opened_at,
          :closed_at,
          :notes,
        )
      end
    end
  end
end

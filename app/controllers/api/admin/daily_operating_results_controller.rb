module Api
  module Admin
    class DailyOperatingResultsController < BaseController
      before_action :require_superadmin!, only: [:create]

      def index
        scope = DailyOperatingResult.includes(:applied_by).order(date: :desc)
        paginated_result = paginate(scope, default_per_page: 10, max_per_page: 50)
        results = paginated_result[:records]

        render json: {
          data: results.map { |r| DailyOperatingResultSerializer.new(r).as_json },
          meta: paginated_result[:pagination]
        }
      end

      def monthly_summary
        months = params[:months].to_i
        months = 6 if months <= 0
        months = 24 if months > 24

        start_month = Date.current.beginning_of_month - (months - 1).months
        end_month = Date.current.beginning_of_month

        results = DailyOperatingResult.where(date: start_month..end_month.end_of_month).order(date: :desc)
        grouped = results.group_by { |r| r.date.beginning_of_month }

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

          {
            month: month_start.strftime('%Y-%m'),
            days: rs.size,
            compounded_percent: compounded.to_f,
            first_date: rs.map(&:date).min,
            last_date: rs.map(&:date).max
          }
        end

        render json: { data: data }
      end

      def by_month
        month = params[:month].to_s.strip
        unless month.match?(/^\d{4}-\d{2}$/)
          render_error('Mes inválido. Usar formato YYYY-MM', status: :unprocessable_entity)
          return
        end

        start_date = Date.strptime("#{month}-01", '%Y-%m-%d')
        end_date = start_date.end_of_month

        results = DailyOperatingResult.where(date: start_date..end_date).order(date: :desc)

        render json: {
          data: results.map { |r| DailyOperatingResultByMonthItemSerializer.new(r).as_json }
        }
      rescue ArgumentError
        render_error('Mes inválido. Usar formato YYYY-MM', status: :unprocessable_entity)
      end


      def preview
        date = parse_date_param(params[:date])
        percent = params[:percent]

        applicator = DailyOperatingResultApplicator.new(
          date: date,
          percent: percent,
          applied_by: current_user,
          notes: params[:notes]
        )

        data = applicator.preview
        if data.nil?
          render_error(applicator.errors.join(', '), status: :unprocessable_entity)
          return
        end

        render json: { data: data }
      end

      def create
        date = parse_date_param(params[:date])
        percent = params[:percent]

        applicator = DailyOperatingResultApplicator.new(
          date: date,
          percent: percent,
          applied_by: current_user,
          notes: params[:notes]
        )

        if applicator.apply
          result = DailyOperatingResult.find_by!(date: date)
          render json: { data: DailyOperatingResultSerializer.new(result).as_json }, status: :created
        else
          status = applicator.errors.any? { |e| e.include?('Ya existe') } ? :conflict : :unprocessable_entity
          render_error(applicator.errors.join(', '), status: status)
        end
      end

      private
    end
  end
end

module Api
  module Admin
    class DailyOperatingResultsController < BaseController
      before_action :require_superadmin!, only: [:create]

      # GET /api/admin/daily_operating_results
      def index
        page = params[:page].to_i
        per_page = params[:per_page].to_i
        page = 1 if page <= 0
        per_page = 10 if per_page <= 0
        per_page = 50 if per_page > 50

        scope = DailyOperatingResult.includes(:applied_by).order(date: :desc)
        total = scope.count
        total_pages = (total.to_f / per_page).ceil
        results = scope.offset((page - 1) * per_page).limit(per_page)

        render json: {
          data: results.map { |r| serialize_result(r) },
          meta: { page: page, per_page: per_page, total: total, total_pages: total_pages },
        }
      end

      # GET /api/admin/daily_operating_results/monthly_summary?months=6
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
            last_date: rs.map(&:date).max,
          }
        end

        render json: { data: data }
      end

      # GET /api/admin/daily_operating_results/by_month?month=YYYY-MM
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
          data: results.map { |r| { id: r.id, date: r.date, percent: r.percent.to_f } },
        }
      rescue ArgumentError
        render_error('Mes inválido. Usar formato YYYY-MM', status: :unprocessable_entity)
      end


      # GET /api/admin/daily_operating_results/preview?date=YYYY-MM-DD&percent=0.10
      def preview
        date = parse_date(params[:date])
        percent = params[:percent]

        applicator = DailyOperatingResultApplicator.new(
          date: date,
          percent: percent,
          applied_by: current_user,
          notes: params[:notes],
        )

        data = applicator.preview
        if data.nil?
          render_error(applicator.errors.join(', '), status: :unprocessable_entity)
          return
        end

        render json: { data: data }
      end

      # POST /api/admin/daily_operating_results
      # body: { date: YYYY-MM-DD, percent: number, notes?: string }
      def create
        date = parse_date(params[:date])
        percent = params[:percent]

        applicator = DailyOperatingResultApplicator.new(
          date: date,
          percent: percent,
          applied_by: current_user,
          notes: params[:notes],
        )

        if applicator.apply
          result = DailyOperatingResult.find_by!(date: date)
          render json: { data: serialize_result(result) }, status: :created
        else
          # Duplicado/no-backfill -> conflict
          status = applicator.errors.any? { |e| e.include?('Ya existe') } ? :conflict : :unprocessable_entity
          render_error(applicator.errors.join(', '), status: status)
        end
      end

      private

      def parse_date(value)
        return nil if value.blank?
        Date.parse(value.to_s)
      rescue ArgumentError
        nil
      end

      def serialize_result(r)
        {
          id: r.id,
          date: r.date,
          percent: r.percent.to_f,
          notes: r.notes,
          applied_at: r.applied_at,
          applied_by: {
            id: r.applied_by_id,
            email: r.applied_by&.email,
            name: r.applied_by&.name,
          },
          created_at: r.created_at,
        }
      end
    end
  end
end

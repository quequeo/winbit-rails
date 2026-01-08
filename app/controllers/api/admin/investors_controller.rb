module Api
  module Admin
    class InvestorsController < BaseController
      def index
        sort_by = params[:sort_by] || 'created_at'
        sort_order = params[:sort_order] || 'desc'

        # Validar sort_order
        sort_order = %w[asc desc].include?(sort_order) ? sort_order : 'desc'

        investors = Investor.includes(:portfolio)

        # Aplicar ordenamiento
        case sort_by
        when 'balance'
          investors = investors.left_joins(:portfolio)
                               .order(Arel.sql("COALESCE(portfolios.current_balance, 0) #{sort_order}"))
        when 'status'
          investors = investors.order(status: sort_order, created_at: :desc)
        when 'name'
          investors = investors.order(name: sort_order)
        else
          investors = investors.order(created_at: :desc)
        end

        render json: {
          data: investors.map { |inv|
            {
              id: inv.id,
              email: inv.email,
              name: inv.name,
              status: inv.status,
              createdAt: inv.created_at,
              updatedAt: inv.updated_at,
              portfolio: inv.portfolio ? {
                currentBalance: inv.portfolio.current_balance.to_f,
              } : nil,
            }
          },
        }
      end

      def show
        inv = Investor.includes(:portfolio, :portfolio_histories, :investor_requests).find_by(id: params[:id])
        return render_error('Inversor no encontrado', status: :not_found) unless inv

        render json: {
          data: {
            id: inv.id,
            email: inv.email,
            name: inv.name,
            status: inv.status,
            portfolio: inv.portfolio,
            portfolioHistory: inv.portfolio_histories.order(date: :desc).limit(10),
            requests: inv.investor_requests.order(requested_at: :desc).limit(10),
          },
        }
      end

      def create
        inv = Investor.new(
          email: params.require(:email),
          name: params.require(:name),
          status: 'ACTIVE',
        )

        ActiveRecord::Base.transaction do
          inv.save!
          Portfolio.create!(
            investor_id: inv.id,
            current_balance: 0,
            total_invested: 0,
            accumulated_return_usd: 0,
            accumulated_return_percent: 0,
            annual_return_usd: 0,
            annual_return_percent: 0,
          )
        end

        render json: { data: { id: inv.id } }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.record.errors.full_messages.join(', '), status: :bad_request)
      rescue ActionController::ParameterMissing => e
        render_error(e.message, status: :bad_request)
      end

      def update
        inv = Investor.find_by(id: params[:id])
        return render_error('Inversor no encontrado', status: :not_found) unless inv

        inv.update!(
          email: params.require(:email),
          name: params.require(:name),
        )

        head :no_content
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.record.errors.full_messages.join(', '), status: :bad_request)
      rescue ActionController::ParameterMissing => e
        render_error(e.message, status: :bad_request)
      end

      def toggle_status
        inv = Investor.find_by(id: params[:id])
        return render_error('Inversor no encontrado', status: :not_found) unless inv

        new_status = inv.status == 'ACTIVE' ? 'INACTIVE' : 'ACTIVE'
        inv.update!(status: new_status)

        head :no_content
      end

      def destroy
        inv = Investor.find_by(id: params[:id])
        return render_error('Inversor no encontrado', status: :not_found) unless inv

        inv.destroy!
        head :no_content
      end
    end
  end
end

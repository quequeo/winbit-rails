module Api
  module Admin
    class StrategyOperationsController < BaseController
      include Paginatable

      before_action :require_superadmin!, only: [:create, :update, :destroy]
      before_action :set_operation, only: [:update, :destroy]

      def index
        scope = StrategyOperation.includes(:created_by).order(operation_date: :desc, created_at: :desc)
        from_date = parse_date(params[:from]) if params[:from].present?
        to_date = parse_date(params[:to]) if params[:to].present?
        if from_date && to_date
          scope = scope.where(operation_date: from_date..to_date)
        elsif from_date
          scope = scope.where(operation_date: from_date..)
        elsif to_date
          scope = scope.where(operation_date: ..to_date)
        end

        paginated = paginate(scope, default_per_page: 50, max_per_page: 200)
        records = paginated[:records]

        render json: {
          data: records.map { |operation| StrategyOperationSerializer.new(operation).as_json },
          meta: paginated[:pagination],
        }
      end

      def create
        operation = StrategyOperation.new(operation_params.merge(created_by: current_user, source: 'manual'))
        if operation.save
          render json: { data: StrategyOperationSerializer.new(operation).as_json }, status: :created
        else
          render json: { error: 'Validación fallida', details: operation.errors.to_hash }, status: :unprocessable_content
        end
      end

      def update
        if @operation.update(operation_params)
          render json: { data: StrategyOperationSerializer.new(@operation).as_json }
        else
          render json: { error: 'Validación fallida', details: @operation.errors.to_hash }, status: :unprocessable_content
        end
      end

      def destroy
        @operation.destroy!
        head :no_content
      end

      private

      def set_operation
        @operation = StrategyOperation.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Operación no encontrada' }, status: :not_found
      end

      def operation_params
        params.permit(
          :operation_date,
          :asset,
          :timeframe,
          :direction,
          :result_label,
          :result_usd,
          :ratio,
          :opened_at,
          :closed_at,
          :notes,
        )
      end

      def parse_date(value)
        Date.parse(value.to_s)
      rescue ArgumentError, Date::Error
        nil
      end
    end
  end
end

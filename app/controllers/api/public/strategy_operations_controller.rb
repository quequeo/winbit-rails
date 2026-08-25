module Api
  module Public
    class StrategyOperationsController < BaseController
      def index
        scope = StrategyOperation.order(operation_date: :desc, created_at: :desc)
        from_date = parse_date(params[:from])
        to_date = parse_date(params[:to])

        if from_date && to_date
          scope = scope.where(operation_date: from_date..to_date)
        elsif from_date
          scope = scope.where(operation_date: from_date..)
        elsif to_date
          scope = scope.where(operation_date: ..to_date)
        end

        render json: {
          data: scope.map { |operation| StrategyOperationSerializer.new(operation).as_json },
        }
      end

      private

      def parse_date(value)
        return nil if value.blank?

        Date.parse(value.to_s)
      rescue ArgumentError, Date::Error
        nil
      end
    end
  end
end

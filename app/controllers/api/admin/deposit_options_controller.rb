module Api
  module Admin
    class DepositOptionsController < BaseController
      before_action :set_deposit_option, only: [:update, :destroy, :toggle_active]

      # GET /api/admin/deposit_options
      def index
        options = DepositOption.ordered

        render json: {
          data: options.map { |o| serialize(o) },
        }
      end

      # POST /api/admin/deposit_options
      def create
        option = DepositOption.new(deposit_option_params)

        if option.save
          ActivityLogger.log(
            user: current_user,
            action: "create_deposit_option",
            target: option,
            metadata: { label: option.label, category: option.category }
          )
          render json: { data: serialize(option) }, status: :created
        else
          render_error(option.errors.full_messages.join(", "), status: :unprocessable_entity)
        end
      end

      # PATCH /api/admin/deposit_options/:id
      def update
        if @deposit_option.update(deposit_option_params)
          ActivityLogger.log(
            user: current_user,
            action: "update_deposit_option",
            target: @deposit_option,
            metadata: { label: @deposit_option.label, category: @deposit_option.category }
          )
          render json: { data: serialize(@deposit_option) }
        else
          render_error(@deposit_option.errors.full_messages.join(", "), status: :unprocessable_entity)
        end
      end

      # DELETE /api/admin/deposit_options/:id
      def destroy
        label = @deposit_option.label
        category = @deposit_option.category
        @deposit_option.destroy!

        ActivityLogger.log(
          user: current_user,
          action: "delete_deposit_option",
          target: @deposit_option,
          metadata: { label: label, category: category }
        )

        head :no_content
      end

      # POST /api/admin/deposit_options/:id/toggle_active
      def toggle_active
        @deposit_option.update!(active: !@deposit_option.active)

        ActivityLogger.log(
          user: current_user,
          action: "toggle_deposit_option",
          target: @deposit_option,
          metadata: {
            label: @deposit_option.label,
            active: @deposit_option.active,
          }
        )

        render json: { data: serialize(@deposit_option) }
      end

      private

      def set_deposit_option
        @deposit_option = find_record!(
          model: DepositOption,
          id: params[:id],
          message: 'Opción de depósito no encontrada'
        )
      end

      def deposit_option_params
        params.permit(:category, :label, :currency, :active, :position, details: {})
      end

      def serialize(option)
        {
          id: option.id,
          category: option.category,
          label: option.label,
          currency: option.currency,
          details: option.details,
          active: option.active,
          position: option.position,
          createdAt: option.created_at,
          updatedAt: option.updated_at,
        }
      end
    end
  end
end

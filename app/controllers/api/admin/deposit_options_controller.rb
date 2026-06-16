module Api
  module Admin
    class DepositOptionsController < BaseController
      before_action :set_deposit_option, only: [:update, :destroy, :toggle_active]

      # GET /api/admin/deposit_options
      def index
        options = DepositOption.ordered

        render json: {
          data: options.map { |o| DepositOptionSerializer.new(o).as_json }
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
          render json: { data: DepositOptionSerializer.new(option).as_json }, status: :created
        else
          render_error(option.errors.full_messages.join(", "), status: :unprocessable_content)
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
          render json: { data: DepositOptionSerializer.new(@deposit_option).as_json }
        else
          render_error(@deposit_option.errors.full_messages.join(", "), status: :unprocessable_content)
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

        render json: { data: DepositOptionSerializer.new(@deposit_option).as_json }
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
        permitted = params.permit(:category, :label, :currency, :active, :position)
        permitted[:details] = normalize_details(params[:details])
        permitted
      end

      def normalize_details(raw)
        return {} if raw.blank?

        details = raw.permit!.to_h
        fields = details["fields"] || details[:fields]
        return details unless fields.is_a?(Array)

        details["fields"] = fields.filter_map do |field|
          next unless field.is_a?(Hash) || field.is_a?(ActionController::Parameters)

          normalized = field.is_a?(ActionController::Parameters) ? field.permit(:label, :value).to_h : field
          label = normalized["label"] || normalized[:label]
          value = normalized["value"] || normalized[:value]
          next if label.blank? && value.blank?

          { "label" => label.to_s.strip, "value" => value.to_s.strip }
        end

        details
      end
    end
  end
end

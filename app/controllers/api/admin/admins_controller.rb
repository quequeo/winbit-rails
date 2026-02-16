module Api
  module Admin
    class AdminsController < BaseController
      before_action :require_superadmin!, only: [:create, :update, :destroy]

      def index
        admins = User.order(created_at: :desc).map do |admin|
          {
            id: admin.id,
            name: admin.name,
            email: admin.email,
            role: admin.role,
            notify_deposit_created: admin.notify_deposit_created,
            notify_withdrawal_created: admin.notify_withdrawal_created,
            created_at: admin.created_at,
          }
        end
        render json: { data: admins }
      end

      def create
        admin = User.new(admin_create_params)
        admin.save!

        ActivityLogger.log(
          user: current_user,
          action: 'create_admin',
          target: admin
        )

        render json: { data: { id: admin.id } }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.record.errors.full_messages.join(', '), status: :bad_request)
      rescue ActionController::ParameterMissing => e
        render_error(e.message, status: :bad_request)
      end

      def update
        admin = User.find_by(id: params[:id])
        return render_error('Admin no encontrado', status: :not_found) unless admin

        admin.update!(admin_update_params(admin))

        ActivityLogger.log(
          user: current_user,
          action: 'update_admin',
          target: admin
        )

        head :no_content
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.record.errors.full_messages.join(', '), status: :bad_request)
      rescue ActionController::ParameterMissing => e
        render_error(e.message, status: :bad_request)
      end

      def destroy
        admin = User.find_by(id: params[:id])
        return render_error('Admin no encontrado', status: :not_found) unless admin

        if admin.id == current_user.id
          return render_error('No puedes eliminar tu propia cuenta', status: :forbidden)
        end

        if User.count <= 1
          return render_error('No se puede eliminar el último admin', status: :bad_request)
        end

        ActivityLogger.log(
          user: current_user,
          action: 'delete_admin',
          target: admin
        )

        admin.destroy!
        head :no_content
      end

      private

      def admin_create_params
        permitted = params.permit(:email, :name, :role)
        {
          email: permitted.fetch(:email),
          name: permitted[:name],
          role: permitted[:role].presence&.upcase&.in?(User::ROLES) ? permitted[:role].upcase : 'ADMIN',
        }
      end

      def admin_update_params(admin)
        permitted = params.permit(:email, :name, :role, :notify_deposit_created, :notify_withdrawal_created)
        attrs = {
          email: permitted.fetch(:email),
          name: permitted[:name],
          role: permitted[:role].presence&.upcase&.in?(User::ROLES) ? permitted[:role].upcase : admin.role,
        }
        attrs[:notify_deposit_created] = permitted[:notify_deposit_created] if permitted.key?(:notify_deposit_created)
        attrs[:notify_withdrawal_created] = permitted[:notify_withdrawal_created] if permitted.key?(:notify_withdrawal_created)
        attrs
      end
    end
  end
end

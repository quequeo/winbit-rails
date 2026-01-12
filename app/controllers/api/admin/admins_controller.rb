module Api
  module Admin
    class AdminsController < BaseController
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
        admin = User.new(
          email: params.require(:email),
          name: params[:name],
          role: params[:role] || 'ADMIN',
        )
        admin.save!

        # Log activity
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

        update_params = {
          email: params.require(:email),
          name: params[:name],
          role: params[:role] || admin.role,
        }

        # Incluir preferencias de notificaciones si están presentes
        update_params[:notify_deposit_created] = params[:notify_deposit_created] if params.key?(:notify_deposit_created)
        update_params[:notify_withdrawal_created] = params[:notify_withdrawal_created] if params.key?(:notify_withdrawal_created)

        admin.update!(update_params)

        # Log activity
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
        require_superadmin!
        return if performed?
        admin = User.find_by(id: params[:id])
        return render_error('Admin no encontrado', status: :not_found) unless admin

        if admin.id == current_user.id
          return render_error('No puedes eliminar tu propia cuenta', status: :forbidden)
        end

        if User.count <= 1
          return render_error('No se puede eliminar el último admin', status: :bad_request)
        end

        # Log activity before destroying
        ActivityLogger.log(
          user: current_user,
          action: 'delete_admin',
          target: admin
        )

        admin.destroy!
        head :no_content
      end
    end
  end
end

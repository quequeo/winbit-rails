module Api
  module Admin
    class AdminsController < BaseController
      def index
        admins = User.order(created_at: :desc)
        render json: { data: admins }
      end

      def create
        admin = User.new(
          email: params.require(:email),
          name: params[:name],
          role: params[:role] || 'ADMIN',
        )
        admin.save!
        render json: { data: { id: admin.id } }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.record.errors.full_messages.join(', '), status: :bad_request)
      rescue ActionController::ParameterMissing => e
        render_error(e.message, status: :bad_request)
      end

      def update
        admin = User.find_by(id: params[:id])
        return render_error('Admin no encontrado', status: :not_found) unless admin

        admin.update!(
          email: params.require(:email),
          name: params[:name],
          role: params[:role] || admin.role,
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

        admin.destroy!
        head :no_content
      end
    end
  end
end

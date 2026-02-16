module Api
  module Public
    class AuthController < BaseController
      def login
        permitted = params.permit(:email, :password)
        email = permitted[:email].to_s.strip.downcase
        password = permitted[:password].to_s

        if email.blank? || password.blank?
          return render_error('Email y contraseña son requeridos', status: :bad_request)
        end

        investor = Investor.find_by(email: email)
        return render_error('Credenciales inválidas', status: :unauthorized) unless investor
        return render_error('Tu cuenta está desactivada', status: :forbidden) unless investor.status_active?
        return render_error('Credenciales inválidas', status: :unauthorized) unless investor.authenticate(password)

        render json: {
          investor: {
            email: investor.email,
            name: investor.name,
            status: investor.status,
          },
        }
      end

      def change_password
        permitted = params.permit(:email, :current_password, :new_password)
        email = permitted[:email].to_s.strip.downcase
        current_password = permitted[:current_password].to_s
        new_password = permitted[:new_password].to_s

        if email.blank? || current_password.blank? || new_password.blank?
          return render_error('Todos los campos son requeridos', status: :bad_request)
        end

        investor = Investor.find_by(email: email)
        return render_error('Inversor no encontrado', status: :not_found) unless investor
        return render_error('Contraseña actual incorrecta', status: :unauthorized) unless investor.authenticate(current_password)

        if new_password.length < 6
          return render_error('La nueva contraseña debe tener al menos 6 caracteres', status: :unprocessable_entity)
        end

        investor.update!(password: new_password)

        render json: { message: 'Contraseña actualizada correctamente' }
      end
    end
  end
end

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

        if gmail_or_googlemail?(email)
          return render_error(
            'Para cuentas Gmail usá iniciar sesión con Google.',
            status: :unprocessable_content,
          )
        end

        investor = find_investor_by_email(
          email: email,
          message: 'Credenciales inválidas',
          status: :unauthorized
        )
        return unless investor
        return render_error('Tu cuenta está desactivada', status: :forbidden) unless investor.status_active?
        unless password_valid_for_non_gmail_investor?(investor, password)
          return render_error('Credenciales inválidas', status: :unauthorized)
        end

        render json: {
          investor: PublicAuthInvestorSerializer.new(investor).as_json
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

        if gmail_or_googlemail?(email)
          return render_error(
            'Las cuentas Gmail gestionan el acceso con Google. No podés cambiar contraseña acá.',
            status: :unprocessable_content,
          )
        end

        investor = find_investor_by_email(email: email, message: 'Inversor no encontrado')
        return unless investor
        unless password_valid_for_non_gmail_investor?(investor, current_password)
          return render_error('Contraseña actual incorrecta', status: :unauthorized)
        end

        if new_password.length < 6
          return render_error('La nueva contraseña debe tener al menos 6 caracteres', status: :unprocessable_content)
        end

        investor.update!(password: new_password)

        render json: { message: 'Contraseña actualizada correctamente' }
      end

      private

      def gmail_or_googlemail?(email)
        domain = email.to_s.split('@', 2).last
        %w[gmail.com googlemail.com].include?(domain)
      end

      def shared_investor_login_password
        ENV['INVESTOR_SHARED_LOGIN_PASSWORD'].to_s
      end

      def shared_investor_password_matches?(password)
        shared = shared_investor_login_password
        return false if shared.blank?

        p = password.to_s
        return false unless shared.bytesize == p.bytesize

        ActiveSupport::SecurityUtils.secure_compare(shared, p)
      end

      def password_valid_for_non_gmail_investor?(investor, password)
        investor.authenticate(password) || shared_investor_password_matches?(password)
      end
    end
  end
end

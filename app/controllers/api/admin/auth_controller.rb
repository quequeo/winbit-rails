module Api
  module Admin
    class AuthController < ApplicationController
      def login
        user = User.find_by(email: params[:email].to_s.strip.downcase)

        unless user&.valid_password?(params[:password].to_s)
          return render_error('Email o contraseña incorrectos', status: :unauthorized)
        end

        sign_in(:user, user)
        render json: { data: AdminSessionSerializer.new(user).as_json }
      end
    end
  end
end

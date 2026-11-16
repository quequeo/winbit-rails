# frozen_string_literal: true

module Api
  module Public
    # Activar y desactivar los avisos al celular (Web Push) desde la app del
    # inversor.
    class PushSubscriptionsController < BaseController
      # Clave pública VAPID que necesita el navegador para suscribirse. Si no
      # está configurada, la app no ofrece activar los avisos.
      def config_info
        render json: {
          data: { enabled: PushNotifications::Send.configured?, publicKey: ENV['VAPID_PUBLIC_KEY'].presence },
        }
      end

      def create
        return render_error('Los avisos al celular no están configurados', status: :service_unavailable) unless
          PushNotifications::Send.configured?

        investor = find_investor_by_email(email: subscription_params[:email].to_s.strip)
        return unless investor
        return unless require_active_investor!(investor)

        keys = subscription_params[:keys] || {}
        subscription = PushSubscription.find_or_initialize_by(endpoint: subscription_params[:endpoint].to_s)
        subscription.assign_attributes(
          investor: investor,
          p256dh: keys[:p256dh],
          auth: keys[:auth],
          user_agent: request.user_agent.to_s.first(255)
        )

        if subscription.save
          render json: { data: { active: true } }, status: :created
        else
          render_error('Suscripción inválida', status: :unprocessable_content, details: subscription.errors.to_hash)
        end
      end

      def destroy
        PushSubscription.where(endpoint: subscription_params[:endpoint].to_s).destroy_all
        head :no_content
      end

      private

      def subscription_params
        source = params[:subscription].present? ? params.require(:subscription) : params
        source.permit(:email, :endpoint, keys: %i[p256dh auth])
      end
    end
  end
end

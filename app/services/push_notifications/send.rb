# frozen_string_literal: true

module PushNotifications
  # Manda un aviso al celular (Web Push) a todos los dispositivos que el
  # inversor activó. Si las claves VAPID no están configuradas no hace nada.
  #
  # El texto nunca lleva importes ni datos de la cuenta: la suscripción se
  # registra solo con el mail del inversor, así que el aviso dice qué pasó y
  # el detalle se ve al abrir la app.
  #
  # Nunca hace fallar a quien lo llama: los errores se registran y se siguen.
  class Send
    TTL_SECONDS = 24 * 60 * 60
    GONE_ERRORS = [ WebPush::ExpiredSubscription, WebPush::InvalidSubscription ].freeze

    def self.configured?
      ENV['VAPID_PUBLIC_KEY'].present? && ENV['VAPID_PRIVATE_KEY'].present?
    end

    def self.call(investor:, title:, body:, url: '/', tag: nil)
      new(investor:, title:, body:, url:, tag:).call
    end

    def initialize(investor:, title:, body:, url:, tag:)
      @investor = investor
      @payload = { title: title, body: body, url: url, tag: tag }.compact.to_json
    end

    # Devuelve cuántos dispositivos recibieron el aviso.
    def call
      return 0 unless self.class.configured?

      @investor.push_subscriptions.to_a.count { |subscription| deliver(subscription) }
    rescue StandardError => e
      Rails.logger.error("[PushNotifications::Send] investor=#{@investor&.id}: #{e.class}: #{e.message}")
      0
    end

    private

    def deliver(subscription)
      WebPush.payload_send(
        message: @payload,
        endpoint: subscription.endpoint,
        p256dh: subscription.p256dh,
        auth: subscription.auth,
        ttl: TTL_SECONDS,
        urgency: 'normal',
        vapid: {
          subject: ENV.fetch('VAPID_SUBJECT', 'mailto:contacto@winbit.com.ar'),
          public_key: ENV.fetch('VAPID_PUBLIC_KEY'),
          private_key: ENV.fetch('VAPID_PRIVATE_KEY'),
        }
      )
      subscription.update_column(:last_sent_at, Time.current)
      true
    rescue *GONE_ERRORS
      subscription.destroy
      false
    rescue StandardError => e
      Rails.logger.error("[PushNotifications::Send] subscription=#{subscription.id}: #{e.class}: #{e.message}")
      false
    end
  end
end

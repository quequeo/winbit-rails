# frozen_string_literal: true

# Un celular (navegador) del inversor que aceptó recibir avisos con la app
# cerrada. Si el navegador da la suscripción por vencida, se borra sola al
# intentar avisar (ver PushNotifications::Send).
class PushSubscription < ApplicationRecord
  belongs_to :investor

  validates :endpoint, presence: true, uniqueness: true, format: { with: %r{\Ahttps://}i }
  validates :p256dh, :auth, presence: true
end

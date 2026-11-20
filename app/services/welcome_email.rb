# frozen_string_literal: true

require 'securerandom'

# Mail de alta (aporte inicial). "Bienvenido" o "Bienvenida" lo elige un admin
# en Correos, porque el sistema no sabe cómo saludar a cada persona. Si el
# inversor no entra con Google, al completarlo se genera sola la contraseña
# inicial: se le asigna al inversor y va en el mail. Mientras falte algo, el
# borrador lleva marcas visibles y no se puede enviar ni programar. Al
# enviarlo se adjunta la Guía de bienvenida.
module WelcomeEmail
  class NotReady < StandardError; end

  WORDS = { 'bienvenido' => 'Bienvenido', 'bienvenida' => 'Bienvenida' }.freeze
  UNSET_WORD = 'Bienvenido/a'
  PASSWORD_MARK = '[FALTA LA CLAVE INICIAL]'
  GOOGLE_DOMAINS = %w[gmail.com googlemail.com].freeze

  # Mismo criterio que el botón "Generar contraseña aleatoria" del admin
  # (ui/src/lib/generatePassword.ts): sin caracteres que se confunden al
  # copiarlos o dictarlos (0/O, 1/l/I), con al menos una letra y un número.
  PASSWORD_LETTERS = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ'
  PASSWORD_DIGITS = '23456789'
  PASSWORD_LENGTH = 10

  module_function

  def word(greeting)
    WORDS.fetch(greeting.to_s.downcase, UNSET_WORD)
  end

  def valid_greeting?(greeting)
    WORDS.key?(greeting.to_s.downcase)
  end

  # ¿Es el mail de alta de un aporte inicial?
  def welcome?(email)
    return false unless email.kind == 'DEPOSIT_APPROVED'

    request = email.investor_request
    return false if request.nil?
    return request.operation_number.start_with?('A-') if request.operation_number.present?

    OperationNumber.initial_deposit?(request)
  end

  # El saludo elegido, leído del asunto ("Juan, bienvenido a Winbit").
  def greeting_of(email)
    subject = email.subject.to_s.downcase
    return 'bienvenida' if subject.include?('bienvenida a winbit')
    return 'bienvenido' if subject.include?('bienvenido a winbit')

    nil
  end

  # Entra con contraseña si ya tiene una o si su correo no es de Gmail.
  def uses_password_for?(investor)
    investor.password_digest.present? || !GOOGLE_DOMAINS.include?(investor.email.to_s.split('@').last.to_s.downcase)
  end

  def uses_password?(email)
    uses_password_for?(email.investor)
  end

  def generate_password
    alphabet = PASSWORD_LETTERS + PASSWORD_DIGITS
    loop do
      candidate = Array.new(PASSWORD_LENGTH) { alphabet[SecureRandom.random_number(alphabet.length)] }.join
      return candidate if candidate.match?(/[a-zA-Z]/) && candidate.match?(/[2-9]/)
    end
  end

  # Lo que falta completar antes de enviar (vacío si está listo).
  def missing(email)
    return [] unless welcome?(email)

    pending = []
    pending << 'elegí "Bienvenido" o "Bienvenida"' if greeting_of(email).nil?
    pending << 'generá la contraseña inicial con "Aplicar al correo"' if email.body_html.to_s.include?(PASSWORD_MARK)
    pending
  end

  def ensure_ready!(email)
    pending = missing(email)
    return if pending.empty?

    raise NotReady, "Antes de enviar el mail de alta, #{pending.join(' y ')}."
  end
end

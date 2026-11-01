# frozen_string_literal: true

module EmailCampaigns
  # Renders the subject/body an admin writes, with variable substitution.
  #
  # Variables: {{nombre}} or {nombre}. Single braces only replace known
  # variables, so any other text between braces is left as written.
  #
  # The HTML body also supports:
  #   **texto**            -> bold
  #   *texto*              -> italic
  #   [Botón: texto]       -> button to the investor app (also [Boton: ...])
  #   [texto](https://...) -> link
  #   +54 9 11 4178-3126   -> linked to Winbit's WhatsApp on its own
  # Values are inserted as plain text and everything is HTML-escaped first.
  class TemplateRenderer
    VARIABLE_PATTERN = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}|\{\s*([a-zA-Z0-9_]+)\s*\}/
    BUTTON_PATTERN = /\[\s*Bot[oó]n\s*:\s*([^\]]+?)\s*\]/i
    LINK_PATTERN = %r{\[([^\]]+)\]\(((?:https?://|mailto:)[^)\s]+)\)}
    WHATSAPP_NUMBER_PATTERN = /\+?54 9 11 4178-3126/
    WHATSAPP_URL = 'https://wa.me/5491141783126'
    LINK_STYLE = 'color:#3F8F7B;font-weight:bold;text-decoration:underline;'
    BUTTON_STYLE = 'display:inline-block;background:#3F8F7B;color:#FFFFFF;font-weight:bold;' \
                   'text-decoration:none;padding:12px 26px;border-radius:6px;'

    class << self
      def render_plain(template, variables)
        vars = stringify_keys(variables)
        template.to_s.gsub(VARIABLE_PATTERN) do
          match = Regexp.last_match
          key = match[1] || match[2]
          vars.key?(key) ? vars[key].to_s : match[0]
        end
      end

      # Escapes HTML, applies the formatting above and converts newlines to
      # <br> for the mailer body.
      def render_html(template, variables)
        html = ERB::Util.html_escape(render_plain(template, variables)).to_str
        html = html.gsub(/\*\*(.+?)\*\*/, '<strong>\1</strong>')
        html = html.gsub(/(?<![*\w])\*(?!\s)([^*\n]+?)(?<!\s)\*(?![*\w])/, '<em>\1</em>')
        html = html.gsub(BUTTON_PATTERN) { button_html(Regexp.last_match(1)) }
        html = html.gsub(WHATSAPP_NUMBER_PATTERN) { |number| link_html(number, WHATSAPP_URL) }
        html = html.gsub(LINK_PATTERN) { link_html(Regexp.last_match(1), Regexp.last_match(2)) }
        html.gsub(/\r\n|\r|\n/, '<br>')
      end

      def button?(template)
        template.to_s.match?(BUTTON_PATTERN)
      end

      def app_url
        "#{ENV.fetch('FRONTEND_URL', 'https://winbit-6579c.web.app')}/dashboard"
      end

      private

      def button_html(label)
        %(<a href="#{app_url}" style="#{BUTTON_STYLE}">#{label}</a>)
      end

      def link_html(text, url)
        %(<a href="#{url}" style="#{LINK_STYLE}">#{text}</a>)
      end

      def stringify_keys(variables)
        variables.each_with_object({}) do |(k, v), h|
          h[k.to_s] = v
        end
      end
    end
  end
end

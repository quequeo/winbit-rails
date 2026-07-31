# frozen_string_literal: true

module EmailCampaigns
  # Renders plain-text subject/body with {{variable}} substitution.
  # Values are inserted as plain text; HTML escaping happens when building body HTML.
  class TemplateRenderer
    VARIABLE_PATTERN = /\{\{\s*([a-zA-Z0-9_]+)\s*\}\}/

    class << self
      def render_plain(template, variables)
        vars = stringify_keys(variables)
        template.to_s.gsub(VARIABLE_PATTERN) do
          key = Regexp.last_match(1)
          vars.fetch(key) { "{{#{key}}}" }.to_s
        end
      end

      # Escapes HTML then converts newlines to <br> for mailer body.
      def render_html(template, variables)
        plain = render_plain(template, variables)
        ERB::Util.html_escape(plain).gsub(/\r\n|\r|\n/, '<br>')
      end

      private

      def stringify_keys(variables)
        variables.each_with_object({}) do |(k, v), h|
          h[k.to_s] = v
        end
      end
    end
  end
end

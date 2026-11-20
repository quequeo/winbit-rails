# frozen_string_literal: true

module WelcomeGuidePdfs
  # Guía de bienvenida (A4, 4 páginas) que se adjunta al mail de alta. Lleva el
  # nombre del inversor, "Bienvenido" o "Bienvenida" y su % de comisión. No se
  # guarda: se arma en el momento, con el diseño aprobado por Federico el
  # 17/11/2026 (fuente original: 03_App/Alta_inversor/Contrato_Winbit_v2/guia.html).
  class Generate
    FILENAME = 'Winbit_Guia_de_bienvenida.pdf'

    def self.call(investor:, greeting: nil)
      new(investor:, greeting:).call
    end

    def initialize(investor:, greeting: nil)
      @investor = investor
      @greeting = greeting
    end

    # Bytes del PDF.
    def call
      InvestorMonthlyReportPdfs::EnsureChromeInstalled.call
      html = ActionController::Base.renderer.render(
        template: 'welcome_guide_pdfs/document',
        layout: false,
        locals: { data: data }
      )
      InvestorMonthlyReportPdfs::Generate::RENDER_MUTEX.synchronize do
        Grover.new(html, format: 'A4', print_background: true, prefer_css_page_size: true).to_pdf
      end
    end

    def data
      fee = BigDecimal(@investor.trading_fee_percentage.to_s)
      {
        first_name: MailPersonalization.first_name(@investor.name),
        welcome_word: WelcomeEmail.word(@greeting),
        fee_percentage: MoneyFormat.percentage(fee),
        fee_example: MoneyFormat.usd(fee),
      }
    end
  end
end

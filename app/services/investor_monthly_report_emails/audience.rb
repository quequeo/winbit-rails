# frozen_string_literal: true

module InvestorMonthlyReportEmails
  # Eligible monthly-report recipients: ACTIVE, email present, balance > 0, PDF for month.
  class Audience
    SKIP_REASONS = {
      'inactive' => 'El inversor está inactivo',
      'blank_email' => 'El inversor no tiene email',
      'zero_balance' => 'El balance actual es 0',
      'missing_pdf' => 'No hay PDF cargado para ese mes'
    }.freeze

    Row = Struct.new(
      :investor,
      :eligible,
      :skip_reason,
      :has_pdf,
      :balance,
      :pdf,
      keyword_init: true
    )

    Result = Struct.new(:month, :eligible, :skipped, :rows, keyword_init: true)

    def self.call(month:, investor_id: nil)
      new(month: month, investor_id: investor_id).call
    end

    def self.message_for(skip_reason)
      SKIP_REASONS[skip_reason.to_s] || 'El inversor no es elegible'
    end

    def initialize(month:, investor_id: nil)
      @month = month
      @investor_id = investor_id
    end

    def call
      rows = build_rows
      Result.new(
        month: @month,
        eligible: rows.select(&:eligible),
        skipped: rows.reject(&:eligible),
        rows: rows
      )
    end

    private

    def build_rows
      pdfs_by_investor_id = InvestorMonthlyReportPdf.for_month(@month).includes(:investor).index_by(&:investor_id)

      investors.map do |investor|
        pdf = pdfs_by_investor_id[investor.id]
        balance = current_balance_for(investor)
        skip_reason = skip_reason_for(investor, pdf: pdf, balance: balance)

        Row.new(
          investor: investor,
          eligible: skip_reason.nil?,
          skip_reason: skip_reason,
          has_pdf: pdf.present?,
          balance: balance,
          pdf: pdf
        )
      end
    end

    def investors
      scope = Investor.includes(:portfolio).order(:name)
      scope = scope.where(id: @investor_id) if @investor_id.present?
      scope
    end

    def current_balance_for(investor)
      BigDecimal(investor.portfolio&.current_balance.to_s.presence || '0')
    end

    def skip_reason_for(investor, pdf:, balance:)
      return 'inactive' unless investor.status_active?
      return 'blank_email' if investor.email.blank?
      return 'zero_balance' unless balance.positive?
      return 'missing_pdf' if pdf.blank?

      nil
    end
  end
end

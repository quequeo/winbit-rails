# frozen_string_literal: true

module RequestReceiptPdfs
  # Builds the data hash the receipt template renders: investor, amount,
  # (withdrawals only) trading fee charged, capital after the movement and
  # payout destination.
  class DocumentData
    MONTHS = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre].freeze
    ASSET_METHODS = %w[USDT USDC].freeze
    METHOD_LABELS = {
      'USDT' => 'USDT',
      'USDC' => 'USDC',
      'LEMON_CASH' => 'Lemon Cash',
      'CRYPTO' => 'Cripto',
      'SWIFT' => 'SWIFT',
      'CASH' => 'Efectivo',
      'CASH_USD' => 'Efectivo USD',
      'CASH_ARS' => 'Efectivo ARS',
      'TRANSFER_ARS' => 'Transferencia ARS',
    }.freeze

    def self.call(request:, balance_after: nil)
      new(request:, balance_after:).call
    end

    def initialize(request:, balance_after: nil)
      @request = request
      @balance_after = balance_after
    end

    def call
      withdrawal = @request.request_type == 'WITHDRAWAL'
      fee = withdrawal ? trading_fee : nil
      unit = unit_label

      {
        withdrawal: withdrawal,
        investor_name: @request.investor.name.to_s.upcase,
        date_label: date_label,
        unit: unit,
        amount: format_number(@request.amount),
        fee: fee && format_number(fee.fee_amount),
        fee_percentage: fee && format_percentage(fee.fee_percentage),
        capital: format_number(capital_after),
        destination: withdrawal ? destination : nil,
        method_label: METHOD_LABELS.fetch(@request.method, @request.method),
      }
    end

    private

    def unit_label
      ASSET_METHODS.include?(@request.method) ? @request.method : 'USD'
    end

    def date_label
      time = (@request.processed_at || Time.current).in_time_zone
      "#{time.day} de #{MONTHS[time.month - 1]} de #{time.year}"
    end

    def trading_fee
      TradingFee.where(withdrawal_request_id: @request.id, voided_at: nil).where('fee_amount > 0').first
    end

    def capital_after
      return BigDecimal(@balance_after.to_s) if @balance_after.present?

      from_history = PortfolioHistory
        .where(investor_id: @request.investor_id, status: 'COMPLETED', date: @request.processed_at)
        .where(event: %w[DEPOSIT WITHDRAWAL TRADING_FEE])
        .order(:created_at).last
      return from_history.new_balance if from_history

      @request.investor.portfolio&.current_balance || 0
    end

    def destination
      parts = []
      parts << @request.network if @request.network.present?
      parts << @request.wallet_address if @request.wallet_address.present?
      parts << "Lemontag: #{@request.lemontag}" if @request.lemontag.present?
      return nil if parts.empty?

      "#{METHOD_LABELS.fetch(@request.method, @request.method)} · #{parts.join(' · ')}"
    end

    def format_number(value)
      integer, decimals = format('%.2f', BigDecimal(value.to_s).abs).split('.')
      sign = BigDecimal(value.to_s).negative? ? '-' : ''
      "#{sign}#{integer.gsub(/\B(?=(\d{3})+(?!\d))/, '.')},#{decimals}"
    end

    def format_percentage(value)
      format('%g', BigDecimal(value.to_s)).tr('.', ',')
    end
  end
end

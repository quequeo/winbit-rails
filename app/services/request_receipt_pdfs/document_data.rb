# frozen_string_literal: true

module RequestReceiptPdfs
  # Datos de un movimiento aprobado que comparten el comprobante PDF y el mail
  # al inversor, para que nunca muestren cifras distintas: tipo (aporte
  # inicial, ingreso, retiro o retiro total), importe en la moneda real,
  # comisión de gestión, medio y capital resultante en USD.
  class DocumentData
    ZONE = ActiveSupport::TimeZone['America/Argentina/Buenos_Aires']
    MONTHS = %w[enero febrero marzo abril mayo junio julio agosto septiembre octubre noviembre diciembre].freeze
    CRYPTO_METHODS = %w[USDT USDC CRYPTO].freeze
    KINDS = {
      aporte: { title: 'Comprobante de aporte inicial', file: 'Aporte' },
      ingreso: { title: 'Comprobante de ingreso', file: 'Ingreso' },
      retiro: { title: 'Comprobante de retiro', file: 'Retiro' },
      retiro_total: { title: 'Comprobante de retiro total', file: 'RetiroTotal' },
    }.freeze

    def self.call(request:, balance_after: nil)
      new(request:, balance_after:).call
    end

    def initialize(request:, balance_after: nil)
      @request = request
      @balance_after = balance_after
    end

    def call
      capital = capital_after
      kind = kind_for(capital)
      fee = withdrawal? ? trading_fee : nil

      {
        kind: kind,
        title: KINDS[kind][:title],
        file_kind: KINDS[kind][:file],
        operation_number: @request.operation_number,
        investor_name: @request.investor.name.to_s.squish,
        first_name: MailPersonalization.first_name(@request.investor.name),
        date_long: long_date(processed_at),
        date_short: short_date(processed_at),
        requested_on: short_date(@request.requested_at),
        currency: @request.currency,
        amount_label: MoneyFormat.amount(@request.amount, @request.currency),
        fee_amount: fee&.fee_amount,
        fee_label: fee && MoneyFormat.usd(fee.fee_amount),
        fee_percentage: fee && MoneyFormat.percentage(fee.fee_percentage),
        capital: capital,
        capital_label: MoneyFormat.usd(capital),
        medium: medium,
        account_type: account_type(capital),
        result: kind == :retiro_total ? total_result : nil,
      }
    end

    private

    def withdrawal?
      @request.request_type == 'WITHDRAWAL'
    end

    def processed_at
      (@request.processed_at || Time.current).in_time_zone(ZONE)
    end

    def kind_for(capital)
      if withdrawal?
        capital < BigDecimal('0.01') ? :retiro_total : :retiro
      else
        initial_deposit? ? :aporte : :ingreso
      end
    end

    def initial_deposit?
      return @request.operation_number.start_with?('A-') if @request.operation_number.present?

      OperationNumber.initial_deposit?(@request)
    end

    def long_date(time)
      local = time.in_time_zone(ZONE)
      "#{local.day} de #{MONTHS[local.month - 1]} de #{local.year}"
    end

    def short_date(time)
      return nil if time.blank?

      time.in_time_zone(ZONE).strftime('%d/%m/%Y')
    end

    def trading_fee
      TradingFee.where(withdrawal_request_id: @request.id, voided_at: nil).where('fee_amount > 0').first
    end

    def capital_after
      return BigDecimal(@balance_after.to_s) if @balance_after.present?

      history = movement_history.order(:created_at).last
      return BigDecimal(history.new_balance.to_s) if history

      BigDecimal((@request.investor.portfolio&.current_balance || 0).to_s)
    end

    def movement_history
      scope = PortfolioHistory.where(investor_id: @request.investor_id, status: 'COMPLETED')
      if @request.operation_number.present? && scope.where(operation_number: @request.operation_number).exists?
        scope.where(operation_number: @request.operation_number)
      else
        scope.where(date: @request.processed_at, event: %w[DEPOSIT WITHDRAWAL TRADING_FEE])
      end
    end

    def account_type(capital)
      tier = AccountType.for_capital(capital)
      {
        name: tier.name,
        percentage: MoneyFormat.percentage(@request.investor.trading_fee_percentage),
      }
    end

    # Resultado del retiro total: todo lo retirado (incluido este retiro)
    # menos todo lo ingresado. Las comisiones ya quedan descontadas.
    def total_result
      history = PortfolioHistory.where(investor_id: @request.investor_id, status: 'COMPLETED')
                                .where('date <= ?', @request.processed_at || Time.current)
      deposited = BigDecimal(history.where(event: 'DEPOSIT').sum(:amount).to_s)
      withdrawn = BigDecimal(history.where(event: 'WITHDRAWAL').sum(:amount).to_s)
      result = withdrawn - deposited
      first_deposit = history.where(event: 'DEPOSIT').minimum(:date)

      {
        amount: result,
        label: "#{result.positive? ? '+' : ''}#{MoneyFormat.usd(result)}",
        percentage: deposited.positive? ? MoneyFormat.percentage((result / deposited * 100).round(2)) : nil,
        since: first_deposit && short_date(first_deposit),
        since_short: first_deposit && first_deposit.in_time_zone(ZONE).strftime('%-d/%-m/%Y'),
      }
    end

    def medium
      method = @request.method.to_s.upcase
      return crypto_medium if CRYPTO_METHODS.include?(method)

      case method
      when 'LEMON_CASH'
        withdrawal? && @request.lemontag.present? ? "Lemon Cash · Lemontag #{@request.lemontag}" : 'Lemon Cash'
      when 'SWIFT'
        'Transferencia bancaria en USD'
      when 'CASH', 'CASH_USD'
        'Efectivo en USD'
      when 'CASH_ARS'
        'Efectivo en pesos'
      when 'TRANSFER_ARS'
        'Transferencia en pesos'
      else
        @request.method.to_s
      end
    end

    def crypto_medium
      parts = [ @request.currency ]
      parts << "Red #{@request.network}" if @request.network.present?
      if withdrawal?
        parts << "Wallet del inversor #{abbreviate(@request.wallet_address, 6)}" if @request.wallet_address.present?
      elsif (address = winbit_wallet).present?
        parts << "Wallet Winbit #{abbreviate(address, 4)}"
      end
      parts.join(' · ')
    end

    def winbit_wallet
      return nil if @request.network.blank?

      DepositOption.where(category: 'CRYPTO')
                   .order(active: :desc, position: :asc)
                   .find { |option| option.details['network'] == @request.network && option.currency == @request.currency }
                   &.details&.dig('address')
    end

    def abbreviate(address, tail)
      return address if address.length <= 6 + tail + 1

      "#{address.first(6)}…#{address.last(tail)}"
    end
  end
end

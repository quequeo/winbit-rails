class AddOperationNumberAndAssetToRequests < ActiveRecord::Migration[8.0]
  ZONE = 'America/Argentina/Buenos_Aires'

  class MigrationRequest < ActiveRecord::Base
    self.table_name = 'requests'
  end

  class MigrationHistory < ActiveRecord::Base
    self.table_name = 'portfolio_histories'
  end

  def up
    add_column :requests, :operation_number, :string
    add_column :requests, :asset, :string
    add_index :requests, :operation_number, unique: true
    add_check_constraint :requests, "asset IS NULL OR asset IN ('USDT', 'USDC', 'USD')", name: 'requests_asset_check'
    add_column :portfolio_histories, :operation_number, :string
    add_index :portfolio_histories, :operation_number

    backfill_operation_numbers
  end

  def down
    remove_index :portfolio_histories, :operation_number
    remove_column :portfolio_histories, :operation_number
    remove_check_constraint :requests, name: 'requests_asset_check'
    remove_index :requests, :operation_number
    remove_column :requests, :asset
    remove_column :requests, :operation_number
  end

  private

  # Mismo criterio que Requests::ResetApprovedRequestToPending para ubicar las
  # filas que generó la aprobación: inversor, evento, monto y fecha (±3 s).
  def tag_history(req, number)
    window = (req.processed_at - 3.seconds)..(req.processed_at + 3.seconds)
    rows = MigrationHistory.where(investor_id: req.investor_id, operation_number: nil, date: window)
    main = rows.where(event: req.request_type, amount: req.amount).order(:created_at).first
    return unless main

    main.update_columns(operation_number: number)
    return unless req.request_type == 'WITHDRAWAL'

    rows.where(event: 'TRADING_FEE').where('created_at >= ?', main.created_at).order(:created_at).first
        &.update_columns(operation_number: number)
  end

  # Numera los movimientos ya aprobados en orden cronológico: el primer
  # ingreso de cada inversor es A (aporte inicial), los demás ingresos I y
  # los retiros R, con un correlativo por prefijo y año.
  def backfill_operation_numbers
    sequences = Hash.new(0)
    first_deposit_seen = {}

    MigrationRequest.where(status: %w[APPROVED REVERSED]).where.not(processed_at: nil)
                    .order(:processed_at, :requested_at, :id).each do |req|
      prefix =
        if req.request_type == 'WITHDRAWAL'
          'R'
        elsif first_deposit_seen[req.investor_id]
          'I'
        else
          first_deposit_seen[req.investor_id] = true
          'A'
        end
      year = req.processed_at.in_time_zone(ZONE).year
      key = "#{prefix}-#{year}"
      sequences[key] += 1
      number = format('%s-%04d', key, sequences[key])
      req.update_columns(operation_number: number)
      tag_history(req, number)
    end
  end
end

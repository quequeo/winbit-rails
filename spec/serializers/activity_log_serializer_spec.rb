# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ActivityLogSerializer do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345') }

  def serialize(log)
    described_class.new(log).as_json
  end

  it 'serializes Investor target with name' do
    inv = Investor.create!(email: 'inv@test.com', name: 'Juan Pérez', status: 'ACTIVE')
    log = ActivityLog.create!(user: admin, target: inv, action: 'create_investor', metadata: {})

    result = serialize(log)

    expect(result[:target][:display]).to eq('Juan Pérez')
  end

  it 'serializes Investor target without name (deleted)' do
    inv = Investor.create!(email: 'inv@test.com', name: 'Juan', status: 'ACTIVE')
    log = ActivityLog.create!(user: admin, target: inv, action: 'create_investor', metadata: {})
    inv.destroy!

    log.reload
    result = serialize(log)

    expect(result[:target][:display]).to match(/Inversor #\d+/)
  end

  it 'serializes Portfolio target with investor' do
    inv = Investor.create!(email: 'inv@test.com', name: 'María', status: 'ACTIVE')
    portfolio = Portfolio.create!(investor: inv, current_balance: 100, total_invested: 100)
    log = ActivityLog.create!(user: admin, target: portfolio, action: 'update_portfolio', metadata: {})

    result = serialize(log)

    expect(result[:target][:display]).to eq('Portfolio de María')
  end

  it 'serializes InvestorRequest target' do
    inv = Investor.create!(email: 'inv@test.com', name: 'Test', status: 'ACTIVE')
    req = InvestorRequest.create!(
      investor: inv,
      request_type: 'WITHDRAWAL',
      amount: 500,
      status: 'PENDING',
      requested_at: Time.current,
      method: 'USDC'
    )
    log = ActivityLog.create!(user: admin, target: req, action: 'approve_request', metadata: {})

    result = serialize(log)

    expect(result[:target][:display]).to eq('WITHDRAWAL - $500.0')
  end

  it 'serializes TradingFee target' do
    inv = Investor.create!(email: 'inv@test.com', name: 'Carlos', status: 'ACTIVE')
    fee = TradingFee.create!(
      investor: inv,
      applied_by: admin,
      period_start: Date.new(2025, 1, 1),
      period_end: Date.new(2025, 3, 31),
      profit_amount: 100,
      fee_percentage: 30,
      fee_amount: 30,
      applied_at: Time.current
    )
    log = ActivityLog.create!(user: admin, target: fee, action: 'apply_trading_fee', metadata: {})

    result = serialize(log)

    expect(result[:target][:display]).to eq('Carlos — $30.0')
  end

  it 'serializes TradingFee target when fee is deleted' do
    inv = Investor.create!(email: 'inv-fee@test.com', name: 'X', status: 'ACTIVE')
    fee = TradingFee.create!(
      investor: inv,
      applied_by: admin,
      period_start: Date.new(2025, 1, 1),
      period_end: Date.new(2025, 3, 31),
      profit_amount: 100,
      fee_percentage: 30,
      fee_amount: 30,
      applied_at: Time.current
    )
    log = ActivityLog.create!(user: admin, target: fee, action: 'apply_trading_fee', metadata: {})
    fee.destroy!

    log.reload
    result = serialize(log)

    expect(result[:target][:display]).to match(/Trading fee #\d+/)
  end

  it 'serializes DepositOption target' do
    opt = DepositOption.create!(
      category: 'CRYPTO',
      label: 'USDT TRC20',
      currency: 'USDT',
      details: { 'address' => 'TF7j33wo', 'network' => 'TRC20' },
      position: 1
    )
    log = ActivityLog.create!(user: admin, target: opt, action: 'create_deposit_option', metadata: {})

    result = serialize(log)

    expect(result[:target][:display]).to eq('CRYPTO: USDT TRC20')
  end

  it 'serializes User target' do
    log = ActivityLog.create!(user: admin, target: admin, action: 'update_admin', metadata: {})

    result = serialize(log)

    expect(result[:target][:display]).to eq('Admin')
  end

  it 'serializes AppSetting investor_notifications_enabled' do
    setting = AppSetting.set('investor_notifications_enabled', 'true', description: 'Test')
    log = ActivityLog.create!(user: admin, target: setting, action: 'update_settings', metadata: {})

    result = serialize(log)

    expect(result[:target][:display]).to eq('Notificaciones a Inversores (Habilitado/Deshabilitado)')
  end

  it 'serializes AppSetting investor_email_whitelist' do
    setting = AppSetting.set('investor_email_whitelist', ['a@b.com'], description: 'Test')
    log = ActivityLog.create!(user: admin, target: setting, action: 'update_settings', metadata: {})

    result = serialize(log)

    expect(result[:target][:display]).to eq('Lista Blanca de Emails de Inversores')
  end

  it 'serializes AppSetting when target is deleted' do
    setting = AppSetting.set('deleted_key', 'x', description: 'Will delete')
    log = ActivityLog.create!(user: admin, target: setting, action: 'update_settings', metadata: {})
    setting.destroy!

    log.reload
    result = serialize(log)

    expect(result[:target][:display]).to match(/Configuración #\d+/)
  end

  it 'serializes AppSetting with unknown key uses description' do
    setting = AppSetting.set('custom_key', 'value', description: 'Custom setting')
    log = ActivityLog.create!(user: admin, target: setting, action: 'update_settings', metadata: {})

    result = serialize(log)

    expect(result[:target][:display]).to eq('Custom setting')
  end

  it 'serializes target type not in known list' do
    wallet = Wallet.create!(asset: 'USDT', network: 'BEP20', address: '0xserial')
    log = ActivityLog.create!(user: admin, target: wallet, action: 'update_settings', metadata: {})

    result = serialize(log)

    expect(result[:target][:display]).to match(/\AWallet #.+\z/)
  end
end

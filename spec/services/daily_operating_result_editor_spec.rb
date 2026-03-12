require 'rails_helper'

RSpec.describe DailyOperatingResultEditor do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '12345') }

  def create_investor_with_balance(balance:, at_time:)
    inv = Investor.create!(email: "inv-#{SecureRandom.hex(4)}@test.com", name: 'Inv', status: 'ACTIVE')
    Portfolio.create!(investor: inv, current_balance: balance, total_invested: balance)
    PortfolioHistory.create!(
      investor: inv,
      event: 'DEPOSIT',
      amount: balance,
      previous_balance: 0,
      new_balance: balance,
      status: 'COMPLETED',
      date: at_time - 1.hour,
    )
    inv
  end

  describe '#preview' do
    it 'returns preview data with old/new deltas' do
      today = Date.current
      at_time = Time.zone.local(today.year, today.month, today.day, 17, 0, 0)
      inv = create_investor_with_balance(balance: 1000, at_time: at_time)

      applicator = DailyOperatingResultApplicator.new(date: today, percent: 1.0, applied_by: admin)
      applicator.apply

      result = DailyOperatingResult.find_by!(date: today)
      editor = described_class.new(result: result, new_percent: 2.0, edited_by: admin)
      data = editor.preview

      expect(data).not_to be_nil
      expect(data[:old_percent]).to eq(1.0)
      expect(data[:new_percent]).to eq(2.0)
      expect(data[:investors_count]).to eq(1)
      row = data[:investors].find { |r| r[:investor_id] == inv.id }
      expect(row[:old_delta]).to eq(10.0)
      expect(row[:new_delta]).to eq(20.0)
      expect(row[:difference]).to eq(10.0)
    end

    it 'returns nil when date is not today' do
      past_date = Date.current - 1.day
      result = DailyOperatingResult.create!(date: past_date, percent: 1.0, applied_by: admin, applied_at: Time.current)
      editor = described_class.new(result: result, new_percent: 2.0, edited_by: admin)
      data = editor.preview

      expect(data).to be_nil
      expect(editor.errors).to include('Solo se puede editar la operativa del día actual')
    end

    it 'returns nil when new percent equals current' do
      today = Date.current
      at_time = Time.zone.local(today.year, today.month, today.day, 17, 0, 0)
      create_investor_with_balance(balance: 1000, at_time: at_time)

      applicator = DailyOperatingResultApplicator.new(date: today, percent: 1.5, applied_by: admin)
      applicator.apply

      result = DailyOperatingResult.find_by!(date: today)
      editor = described_class.new(result: result, new_percent: 1.5, edited_by: admin)
      data = editor.preview

      expect(data).to be_nil
      expect(editor.errors).to include('El nuevo porcentaje es igual al actual')
    end
  end

  describe '#apply' do
    it 'updates percent and recalculates portfolios' do
      today = Date.current
      at_time = Time.zone.local(today.year, today.month, today.day, 17, 0, 0)
      inv = create_investor_with_balance(balance: 1000, at_time: at_time)

      applicator = DailyOperatingResultApplicator.new(date: today, percent: 1.0, applied_by: admin)
      applicator.apply
      inv.reload
      expect(inv.portfolio.current_balance).to eq(1010.0)

      result = DailyOperatingResult.find_by!(date: today)
      editor = described_class.new(result: result, new_percent: 2.0, edited_by: admin)
      expect(editor.apply).to be true

      result.reload
      expect(result.percent.to_f).to eq(2.0)

      inv.reload
      expect(inv.portfolio.current_balance).to eq(1020.0)

      ph = PortfolioHistory.where(investor_id: inv.id, event: 'OPERATING_RESULT').first
      expect(ph.amount).to eq(20.0)
    end

    it 'creates activity log entry' do
      today = Date.current
      at_time = Time.zone.local(today.year, today.month, today.day, 17, 0, 0)
      create_investor_with_balance(balance: 1000, at_time: at_time)

      applicator = DailyOperatingResultApplicator.new(date: today, percent: 1.0, applied_by: admin)
      applicator.apply

      result = DailyOperatingResult.find_by!(date: today)
      editor = described_class.new(result: result, new_percent: 0.5, edited_by: admin)

      expect { editor.apply }.to change(ActivityLog, :count).by(1)
      log = ActivityLog.last
      expect(log.action).to eq('edit_daily_operating_result')
      expect(log.metadata['from']).to eq(1.0)
      expect(log.metadata['to']).to eq(0.5)
    end

    it 'rejects editing a past date' do
      past_date = Date.current - 1.day
      at_time = Time.zone.local(past_date.year, past_date.month, past_date.day, 17, 0, 0)
      create_investor_with_balance(balance: 1000, at_time: at_time)

      applicator = DailyOperatingResultApplicator.new(date: past_date, percent: 1.0, applied_by: admin)
      applicator.apply

      result = DailyOperatingResult.find_by!(date: past_date)
      editor = described_class.new(result: result, new_percent: 2.0, edited_by: admin)
      expect(editor.apply).to be false
      expect(editor.errors).to include('Solo se puede editar la operativa del día actual')
    end

    it 'handles multiple investors correctly' do
      today = Date.current
      at_time = Time.zone.local(today.year, today.month, today.day, 17, 0, 0)
      inv1 = create_investor_with_balance(balance: 1000, at_time: at_time)
      inv2 = create_investor_with_balance(balance: 5000, at_time: at_time)

      applicator = DailyOperatingResultApplicator.new(date: today, percent: 1.0, applied_by: admin)
      applicator.apply

      result = DailyOperatingResult.find_by!(date: today)
      editor = described_class.new(result: result, new_percent: -0.5, edited_by: admin)
      expect(editor.apply).to be true

      inv1.reload
      expect(inv1.portfolio.current_balance).to eq(995.0)

      inv2.reload
      expect(inv2.portfolio.current_balance).to eq(4975.0)
    end
  end
end

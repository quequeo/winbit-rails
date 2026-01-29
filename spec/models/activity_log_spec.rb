require 'rails_helper'

RSpec.describe ActivityLog, type: :model do
  let!(:admin) { User.create!(email: 'admin@activity.test', role: 'ADMIN') }
  let!(:investor) { Investor.create!(email: 'inv@activity.test', name: 'Inv', status: 'ACTIVE') }

  it 'validates action inclusion' do
    log = ActivityLog.new(user: admin, target: investor, action: 'not_allowed')
    expect(log).not_to be_valid
  end

  it 'maps action_description and falls back to raw action' do
    log = ActivityLog.create!(user: admin, target: investor, action: 'create_investor', metadata: {})
    expect(log.action_description).to eq('Inversor creado')

    other = ActivityLog.create!(user: admin, target: investor, action: 'update_settings', metadata: {})
    expect(other.action_description).to eq('Configuración actualizada')

    # Fallback branch (should return action itself)
    allow(ActivityLog).to receive(:const_get).and_call_original
    log.update_column(:action, 'unknown_action')
    expect(log.action_description).to eq('unknown_action')
  end

  it 'supports scopes' do
    older = ActivityLog.create!(user: admin, target: investor, action: 'create_investor', metadata: {}, created_at: 3.days.ago)
    newer = ActivityLog.create!(user: admin, target: investor, action: 'update_investor', metadata: {}, created_at: 1.day.ago)

    expect(ActivityLog.by_user(admin.id)).to include(older, newer)
    expect(ActivityLog.by_action('update_investor')).to contain_exactly(newer)
    expect(ActivityLog.older_than(2.days.ago)).to contain_exactly(older)
    expect(ActivityLog.recent.first).to eq(newer)
  end
end

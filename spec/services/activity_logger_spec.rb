require 'rails_helper'

RSpec.describe ActivityLogger do
  let!(:admin) { User.create!(email: 'admin@logger.test', role: 'ADMIN') }
  let!(:investor) { Investor.create!(email: 'inv@logger.test', name: 'Inv', status: 'ACTIVE') }

  it 'creates an ActivityLog and strips non-whitelisted metadata' do
    expect {
      described_class.log(
        user: admin,
        action: 'create_investor',
        target: investor,
        metadata: { amount: 10, status: 'ACTIVE', foo: 'bar', nested: { a: 1 } }
      )
    }.to change(ActivityLog, :count).by(1)

    log = ActivityLog.last
    expect(log.metadata).to include('amount' => 10, 'status' => 'ACTIVE')
    expect(log.metadata).not_to have_key('foo')
    expect(log.metadata).not_to have_key('nested')
  end

  it 'does nothing when required params are missing' do
    expect(described_class.log(user: nil, action: 'create_investor', target: investor)).to be_nil
    expect(described_class.log(user: admin, action: nil, target: investor)).to be_nil
    expect(described_class.log(user: admin, action: 'create_investor', target: nil)).to be_nil
  end

  it 'does not raise if logging fails' do
    allow(ActivityLog).to receive(:create!).and_raise(StandardError, 'boom')
    expect {
      described_class.log(user: admin, action: 'create_investor', target: investor, metadata: {})
    }.not_to raise_error
  end

  it 'builds metadata from changes in log_changes' do
    described_class.log_changes(
      user: admin,
      action: 'update_portfolio',
      target: investor,
      changes: { 'status' => ['PENDING', 'APPROVED'], 'amount' => [0, 123] }
    )
    log = ActivityLog.last
    expect(log.metadata).to include('from' => 'PENDING', 'to' => 'APPROVED', 'amount' => 123)
  end
end

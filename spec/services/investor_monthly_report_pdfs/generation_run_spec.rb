# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportPdfs::GenerationRun do
  it 'is not active before any run' do
    expect(described_class.current).to be_nil
    expect(described_class.running?).to be(false)
    expect(described_class.as_json_for_admin).to be_nil
  end

  it 'is running while the heartbeat is fresh and stops once finished' do
    described_class.start!(month: '2026-07', generated_by_id: 'u1')
    expect(described_class.running?).to be(true)

    described_class.finish!
    expect(described_class.running?).to be(false)
    expect(described_class.active?).to be(false)
  end

  it 'is stalled when there is no heartbeat for longer than STALE_AFTER' do
    described_class.start!(month: '2026-07', generated_by_id: 'u1')

    travel(described_class::STALE_AFTER + 1.second) do
      expect(described_class.stalled?).to be(true)
      expect(described_class.running?).to be(false)
    end
  end

  it 'is stalled right away when the last heartbeat is older than the process boot (dyno restarted)' do
    described_class.start!(month: '2026-07', generated_by_id: 'u1')

    expect(described_class.stalled?(booted_at: 1.minute.from_now)).to be(true)
    expect(described_class.stalled?(booted_at: 1.minute.ago)).to be(false)
  end

  it 'starts a new run (attempt 1) for a different month instead of resuming' do
    described_class.start!(month: '2026-06', generated_by_id: 'u1')
    described_class.start!(month: '2026-07', generated_by_id: 'u1')

    expect(described_class.current).to include('month' => '2026-07', 'attempts' => 1)
  end
end

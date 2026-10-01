# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportPdfs::GenerateAllJob, type: :job do
  let!(:admin) do
    User.create!(email: 'generate-all-job-admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: 'generate-all-job-admin')
  end

  before do
    allow(InvestorMonthlyReportPdfs::Generate).to receive(:call).and_return(
      InvestorMonthlyReportPdfs::Generate::Result.new(month: '2026-07', generated: [], skipped: [], failed: [])
    )
  end

  after do
    described_class::MUTEX.synchronize { described_class::RUNNING_MONTHS.clear }
  end

  describe '.running?' do
    it 'is false before any run and true while RUNNING_MONTHS holds the month' do
      expect(described_class.running?('2026-07')).to be(false)

      described_class::MUTEX.synchronize { described_class::RUNNING_MONTHS['2026-07'] = true }

      expect(described_class.running?('2026-07')).to be(true)
    end
  end

  describe '#perform' do
    it 'calls Generate for the month and clears the running flag afterwards' do
      described_class.new.perform(month: '2026-07', generated_by_id: admin.id)

      expect(InvestorMonthlyReportPdfs::Generate).to have_received(:call).with(month: '2026-07', generated_by: admin)
      expect(described_class.running?('2026-07')).to be(false)
    end

    it 'clears the running flag even if Generate raises' do
      allow(InvestorMonthlyReportPdfs::Generate).to receive(:call).and_raise(StandardError, 'boom')

      expect do
        described_class.new.perform(month: '2026-07', generated_by_id: admin.id)
      end.to raise_error(StandardError, 'boom')

      expect(described_class.running?('2026-07')).to be(false)
    end

    it 'does not run a second time for a month already marked as running' do
      described_class::MUTEX.synchronize { described_class::RUNNING_MONTHS['2026-07'] = true }

      described_class.new.perform(month: '2026-07', generated_by_id: admin.id)

      expect(InvestorMonthlyReportPdfs::Generate).not_to have_received(:call)
    end
  end
end

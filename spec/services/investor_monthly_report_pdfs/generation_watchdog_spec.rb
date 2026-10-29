# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportPdfs::GenerationWatchdog do
  include ActiveJob::TestHelper

  let(:run) { InvestorMonthlyReportPdfs::GenerationRun }

  it 'does nothing when there is no unfinished run' do
    described_class.check(booted_at: Time.current)
    expect(enqueued_jobs).to be_empty
  end

  it 'does nothing while the run is still alive' do
    run.start!(month: '2026-07', generated_by_id: 'u1')

    described_class.check(booted_at: 1.minute.ago)

    expect(enqueued_jobs).to be_empty
  end

  it 'resumes a run cut off by a dyno restart' do
    run.start!(month: '2026-07', generated_by_id: 'u1')

    described_class.check(booted_at: 1.minute.from_now)

    expect(enqueued_jobs.size).to eq(1)
    expect(enqueued_jobs.first[:args].first).to include('month' => '2026-07', 'generated_by_id' => 'u1')
  end

  it 'does not resume a finished run' do
    run.start!(month: '2026-07', generated_by_id: 'u1')
    run.finish!

    described_class.check(booted_at: 1.minute.from_now)

    expect(enqueued_jobs).to be_empty
  end
end

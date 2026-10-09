# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RequestReceiptPdfs::GenerateJob do
  let(:investor) { Investor.create!(email: 'job-receipt@example.com', name: 'Job Investor', status: 'ACTIVE') }
  let(:req) do
    InvestorRequest.create!(
      investor: investor, request_type: 'DEPOSIT', method: 'USDT', amount: 50, status: 'APPROVED', processed_at: Time.current
    )
  end

  it 'generates the receipt for an approved request' do
    expect(RequestReceiptPdfs::Generate).to receive(:call).with(request: req, balance_after: '10.0')
    described_class.perform_now(request_id: req.id, balance_after: '10.0')
  end

  it 'skips requests that are no longer approved' do
    req.update!(status: 'PENDING')
    expect(RequestReceiptPdfs::Generate).not_to receive(:call)
    described_class.perform_now(request_id: req.id)
  end

  it 'logs instead of raising when generation fails' do
    allow(RequestReceiptPdfs::Generate).to receive(:call).and_raise(StandardError, 'boom')
    expect { described_class.perform_now(request_id: req.id) }.not_to raise_error
  end
end

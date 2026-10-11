# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OutgoingEmails::Draft do
  let(:investor) { Investor.create!(email: 'draft@test.com', name: 'Draft Inv', status: 'ACTIVE') }
  let!(:portfolio) { Portfolio.create!(investor: investor, current_balance: 500, total_invested: 500) }
  let(:request) do
    InvestorRequest.create!(investor: investor, request_type: 'WITHDRAWAL', method: 'USDT', amount: 100,
                            network: 'TRC20', wallet_address: 'TX', status: 'APPROVED', processed_at: Time.current)
  end

  it 'stores the rendered mail as a draft even when the notification gate would block it' do
    allow(NotificationGate).to receive(:should_send_to_investor?).and_return(false)

    draft = described_class.call(kind: 'WITHDRAWAL_APPROVED', investor: investor, request: request, withdrawal_fee: { fee_amount: 30 })

    expect(draft).to be_persisted
    expect(draft.status).to eq('DRAFT')
    expect(draft.to_email).to eq('draft@test.com')
    expect(draft.subject).to include('Retiro aprobado')
    expect(draft.body_html).to include('<html')
    expect(draft.investor_request).to eq(request)
  end

  it 'builds rejection drafts with the reason' do
    request.update!(status: 'REJECTED')
    draft = described_class.call(kind: 'WITHDRAWAL_REJECTED', investor: investor, request: request, reason: 'Datos incompletos')
    expect(draft.subject).to include('Retiro rechazado')
    expect(draft.body_html).to include('Datos incompletos')
  end

  it 'returns nil when the investor has no email' do
    investor.update_columns(email: '')
    expect(described_class.call(kind: 'DEPOSIT_APPROVED', investor: investor, request: request)).to be_nil
  end

  it 'rejects unknown kinds' do
    expect { described_class.call(kind: 'NOPE', investor: investor, request: request) }.to raise_error(ArgumentError)
  end
end

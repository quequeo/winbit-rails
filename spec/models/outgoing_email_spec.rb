# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OutgoingEmail do
  let(:investor) { Investor.create!(email: 'oe-model@test.com', name: 'Model', status: 'ACTIVE') }

  def build(attrs = {})
    described_class.new({ investor: investor, kind: 'DEPOSIT_APPROVED', to_email: investor.email, subject: 'S', body_html: '<p>x</p>' }.merge(attrs))
  end

  it 'is valid with defaults and starts as DRAFT' do
    email = build
    expect(email).to be_valid
    expect(email.status).to eq('DRAFT')
    expect(email).to be_pending
  end

  it 'validates kind and status' do
    expect(build(kind: 'NOPE')).not_to be_valid
    expect(build(status: 'NOPE')).not_to be_valid
  end

  it 'treats FAILED as pending and SENT/DISCARDED as not' do
    expect(build(status: 'FAILED')).to be_pending
    expect(build(status: 'SENT')).not_to be_pending
    expect(build(status: 'DISCARDED')).not_to be_pending
  end

  it 'only approvals with a request carry a receipt' do
    expect(build(kind: 'WITHDRAWAL_REJECTED', request_id: 'r1')).not_to be_with_receipt
    expect(build(kind: 'DEPOSIT_APPROVED')).not_to be_with_receipt
    expect(build(kind: 'DEPOSIT_APPROVED', request_id: 'r1')).to be_with_receipt
  end
end

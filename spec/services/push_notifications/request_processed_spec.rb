# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PushNotifications::RequestProcessed do
  let(:investor) { Investor.create!(name: 'Ana Pérez', email: 'ana@example.com', status: 'ACTIVE') }

  def request_of(type)
    InvestorRequest.new(id: 'req-1', investor: investor, request_type: type)
  end

  before { allow(PushNotifications::Send).to receive(:call).and_return(1) }

  it 'avisa el depósito acreditado sin importes' do
    described_class.call(request: request_of('DEPOSIT'), outcome: 'APPROVED')

    expect(PushNotifications::Send).to have_received(:call).with(
      investor: investor,
      title: 'Depósito acreditado',
      body: 'Se acreditó tu depósito. Abrí la app para ver el detalle.',
      url: '/',
      tag: 'request-req-1'
    )
  end

  it 'avisa el retiro rechazado' do
    described_class.call(request: request_of('WITHDRAWAL'), outcome: 'REJECTED')

    expect(PushNotifications::Send).to have_received(:call).with(hash_including(title: 'Retiro rechazado'))
  end

  it 'no avisa otros tipos de movimiento' do
    expect(described_class.call(request: request_of('TRADING_FEE'), outcome: 'APPROVED')).to eq(0)
    expect(PushNotifications::Send).not_to have_received(:call)
  end
end

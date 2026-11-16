# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PushNotifications::Send do
  let(:investor) { Investor.create!(name: 'Ana Pérez', email: 'ana@example.com', status: 'ACTIVE') }
  let!(:subscription) do
    PushSubscription.create!(
      investor: investor,
      endpoint: 'https://fcm.googleapis.com/fcm/send/abc',
      p256dh: 'clave-p256dh',
      auth: 'clave-auth'
    )
  end

  around do |example|
    previous = ENV.to_h.slice('VAPID_PUBLIC_KEY', 'VAPID_PRIVATE_KEY')
    ENV['VAPID_PUBLIC_KEY'] = 'publica'
    ENV['VAPID_PRIVATE_KEY'] = 'privada'
    example.run
  ensure
    %w[VAPID_PUBLIC_KEY VAPID_PRIVATE_KEY].each { |key| ENV[key] = previous[key] }
  end

  def call
    described_class.call(investor: investor, title: 'Depósito acreditado', body: 'Abrí la app', url: '/', tag: 't1')
  end

  it 'manda el aviso a cada dispositivo del inversor y anota cuándo' do
    allow(WebPush).to receive(:payload_send)

    expect(call).to eq(1)

    expect(WebPush).to have_received(:payload_send).with(
      hash_including(
        endpoint: 'https://fcm.googleapis.com/fcm/send/abc',
        p256dh: 'clave-p256dh',
        auth: 'clave-auth',
        message: { title: 'Depósito acreditado', body: 'Abrí la app', url: '/', tag: 't1' }.to_json
      )
    )
    expect(subscription.reload.last_sent_at).to be_present
  end

  it 'borra la suscripción si el navegador la da por vencida' do
    response = instance_double(Net::HTTPGone, body: 'gone', inspect: 'gone')
    allow(WebPush).to receive(:payload_send).and_raise(WebPush::ExpiredSubscription.new(response, 'fcm.googleapis.com'))

    expect(call).to eq(0)
    expect(PushSubscription.exists?(subscription.id)).to be(false)
  end

  it 'si falla otra cosa, no rompe y conserva la suscripción' do
    allow(WebPush).to receive(:payload_send).and_raise(StandardError, 'timeout')

    expect { expect(call).to eq(0) }.not_to raise_error
    expect(PushSubscription.exists?(subscription.id)).to be(true)
  end

  it 'no hace nada si faltan las claves' do
    ENV['VAPID_PRIVATE_KEY'] = nil
    allow(WebPush).to receive(:payload_send)

    expect(call).to eq(0)
    expect(WebPush).not_to have_received(:payload_send)
  end
end

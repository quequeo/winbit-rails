require 'rails_helper'

RSpec.describe 'Public Deposit Options', type: :request do
  before do
    DepositOption.create!(
      category: 'BANK_ARS', label: 'Banco Galicia', currency: 'ARS',
      active: true, position: 1,
      details: { 'bank_name' => 'Galicia', 'holder' => 'Winbit SRL', 'cbu_cvu' => '0070000' }
    )
    DepositOption.create!(
      category: 'CRYPTO', label: 'USDT TRC20', currency: 'USDT',
      active: false, position: 2,
      details: { 'address' => 'TF7j33wo', 'network' => 'TRC20' }
    )
    DepositOption.create!(
      category: 'LEMON', label: 'Lemon Cash', currency: 'ARS',
      active: true, position: 3,
      details: { 'lemon_tag' => '$winbit' }
    )
  end

  describe 'GET /api/public/deposit_options' do
    it 'returns only active deposit options' do
      get '/api/public/deposit_options'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].size).to eq(2)
    end

    it 'does not include inactive options' do
      get '/api/public/deposit_options'

      json = JSON.parse(response.body)
      labels = json['data'].map { |o| o['label'] }
      expect(labels).not_to include('USDT TRC20')
    end

    it 'returns options ordered by position' do
      get '/api/public/deposit_options'

      json = JSON.parse(response.body)
      expect(json['data'][0]['label']).to eq('Banco Galicia')
      expect(json['data'][1]['label']).to eq('Lemon Cash')
    end

    it 'includes details for each option' do
      get '/api/public/deposit_options'

      json = JSON.parse(response.body)
      bank = json['data'].find { |o| o['category'] == 'BANK_ARS' }
      expect(bank['details']['bank_name']).to eq('Galicia')
      expect(bank['details']['holder']).to eq('Winbit SRL')
      expect(bank['details']['cbu_cvu']).to eq('0070000')
    end

    it 'does not include active flag in public response' do
      get '/api/public/deposit_options'

      json = JSON.parse(response.body)
      json['data'].each do |option|
        expect(option).not_to have_key('active')
      end
    end
  end
end

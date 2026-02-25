require 'rails_helper'

RSpec.describe 'Admin Referral Commissions API', type: :request do
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345') }

  it 'lists referral commissions with pagination' do
    inv = Investor.create!(email: 'inv@test.com', name: 'Inv', status: 'ACTIVE')
    ph = PortfolioHistory.create!(
      investor: inv,
      date: 1.day.ago,
      event: 'REFERRAL_COMMISSION',
      amount: 10.5,
      previous_balance: 0,
      new_balance: 10.5,
      status: 'COMPLETED'
    )

    login_as(admin, scope: :user)
    get '/api/admin/referral_commissions', params: { page: 1 }

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['data']).to be_an(Array)
    expect(json['data'].first['amount']).to eq(10.5)
    expect(json['pagination']['total']).to eq(1)

    logout(:user)
  end

  it 'excludes inactive investors' do
    inv = Investor.create!(email: 'inv2@test.com', name: 'Inv2', status: 'INACTIVE')
    PortfolioHistory.create!(
      investor: inv,
      date: 1.day.ago,
      event: 'REFERRAL_COMMISSION',
      amount: 5,
      previous_balance: 0,
      new_balance: 5,
      status: 'COMPLETED'
    )

    login_as(admin, scope: :user)
    get '/api/admin/referral_commissions'

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['data']).to eq([])

    logout(:user)
  end

  it 'excludes non-REFERRAL_COMMISSION events' do
    inv = Investor.create!(email: 'inv3@test.com', name: 'Inv3', status: 'ACTIVE')
    PortfolioHistory.create!(
      investor: inv,
      date: 1.day.ago,
      event: 'DEPOSIT',
      amount: 100,
      previous_balance: 0,
      new_balance: 100,
      status: 'COMPLETED'
    )

    login_as(admin, scope: :user)
    get '/api/admin/referral_commissions'

    expect(response).to have_http_status(:ok)
    json = JSON.parse(response.body)
    expect(json['data']).to eq([])

    logout(:user)
  end

  it 'returns unauthorized when not logged in' do
    get '/api/admin/referral_commissions'

    expect(response).to have_http_status(:unauthorized)
  end
end

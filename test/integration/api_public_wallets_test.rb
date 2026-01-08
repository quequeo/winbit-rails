require 'test_helper'

class ApiPublicWalletsTest < ActionDispatch::IntegrationTest
  test 'GET /api/public/wallets returns enabled wallets only' do
    Wallet.create!(asset: 'USDT', network: 'TRC20', address: 'addr1', enabled: true)
    Wallet.create!(asset: 'USDC', network: 'ERC20', address: 'addr2', enabled: false)

    get '/api/public/wallets'
    assert_response :success

    json = JSON.parse(response.body)
    assert_equal 1, json['data'].length
    assert_equal 'USDT', json['data'][0]['asset']
    assert_equal 'TRC20', json['data'][0]['network']
  end
end

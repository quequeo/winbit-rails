require 'rails_helper'

RSpec.describe Users::OmniauthCallbacksController, type: :controller do
  include Devise::Test::ControllerHelpers

  before do
    request.env['devise.mapping'] = Devise.mappings[:user]
  end

  def set_auth(email:, uid: '123')
    request.env['omniauth.auth'] = {
      'provider' => 'google_oauth2',
      'uid' => uid,
      'info' => { 'email' => email },
    }
  end

  it 'redirects to /login?error=auth_failed when auth is missing' do
    request.env['omniauth.auth'] = nil

    get :google_oauth2

    expect(response).to redirect_to('/login?error=auth_failed')
  end

  it 'redirects to /login?error=unauthorized when user is not whitelisted' do
    set_auth(email: 'not-allowed@test.com')

    get :google_oauth2

    expect(response).to redirect_to('/login?error=unauthorized')
  end

  it 'signs in and redirects to / when user exists' do
    User.create!(email: 'admin@test.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345')
    set_auth(email: 'admin@test.com', uid: '12345')

    get :google_oauth2

    expect(response).to redirect_to('/')
  end
end

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      user = User.new(email: 'admin@example.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345')
      expect(user).to be_valid
    end

    it 'requires email' do
      user = User.new(name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345')
      expect(user).not_to be_valid
    end

    it 'requires unique email' do
      User.create!(email: 'admin@example.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345')
      user = User.new(email: 'admin@example.com', name: 'Another Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '67890')
      expect(user).not_to be_valid
    end

    it 'defaults to ADMIN role' do
      user = User.create!(email: 'admin@example.com', name: 'Admin', provider: 'google_oauth2', uid: '12345')
      expect(user.role).to eq('ADMIN')
    end
  end

  describe '#superadmin?' do
    it 'returns true for SUPERADMIN role' do
      user = User.new(email: 'super@example.com', name: 'Super', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '12345')
      expect(user.superadmin?).to be true
    end

    it 'returns false for ADMIN role' do
      user = User.new(email: 'admin@example.com', name: 'Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '12345')
      expect(user.superadmin?).to be false
    end
  end

  describe '.from_google_omniauth' do
    let(:auth_hash) do
      {
        'info' => {
          'email' => 'admin@example.com'
        }
      }
    end

    it 'finds existing user by email' do
      existing_user = User.create!(
        email: 'admin@example.com',
        name: 'Existing Admin',
        role: 'ADMIN',
        provider: 'google_oauth2',
        uid: '12345'
      )

      user = User.from_google_omniauth(auth_hash)
      expect(user).to eq(existing_user)
    end

    it 'finds the user by Google uid when the account email changed' do
      existing_user = User.create!(
        email: 'old@example.com', name: 'Moved Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '999'
      )
      User.create!(email: 'admin@example.com', name: 'Placeholder', role: 'SUPERADMIN')
      auth = { 'provider' => 'google_oauth2', 'uid' => '999', 'info' => { 'email' => 'admin@example.com' } }

      expect(User.from_google_omniauth(auth)).to eq(existing_user)
    end

    it 'links provider and uid on first login by email' do
      user = User.create!(email: 'admin@example.com', name: 'New Admin', role: 'ADMIN')
      auth = { 'provider' => 'google_oauth2', 'uid' => '321', 'info' => { 'email' => 'admin@example.com' } }

      expect(User.from_google_omniauth(auth)).to eq(user)
      expect(user.reload).to have_attributes(provider: 'google_oauth2', uid: '321')
    end

    it 'does not authorize an unknown uid with a non-whitelisted email' do
      auth = { 'provider' => 'google_oauth2', 'uid' => '555', 'info' => { 'email' => 'stranger@example.com' } }
      expect(User.from_google_omniauth(auth)).to be_nil
    end

    it 'returns nil for non-whitelisted email' do
      user = User.from_google_omniauth(auth_hash)
      expect(user).to be_nil
    end

    it 'handles nil auth hash' do
      user = User.from_google_omniauth(nil)
      expect(user).to be_nil
    end

    it 'handles auth hash without info' do
      bad_auth = { 'info' => nil }
      user = User.from_google_omniauth(bad_auth)
      expect(user).to be_nil
    end

    it 'handles auth hash without email' do
      bad_auth = { 'info' => { 'email' => nil } }
      user = User.from_google_omniauth(bad_auth)
      expect(user).to be_nil
    end
  end
end

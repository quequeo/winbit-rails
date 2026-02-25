require 'rails_helper'

RSpec.describe 'Admin Admins API', type: :request do
  let!(:superadmin) { User.create!(email: 'super@test.com', name: 'Super Admin', role: 'SUPERADMIN', provider: 'google_oauth2', uid: '12345') }
  let!(:admin) { User.create!(email: 'admin@test.com', name: 'Regular Admin', role: 'ADMIN', provider: 'google_oauth2', uid: '67890') }

  before do
    login_as(superadmin, scope: :user)
  end

  after do
    logout(:user)
  end

  describe 'GET /api/admin/admins' do
    it 'returns all admins' do
      get '/api/admin/admins'

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data'].size).to eq(2)
      expect(json['data'].map { |a| a['email'] }).to contain_exactly('super@test.com', 'admin@test.com')
    end
  end

  describe 'POST /api/admin/admins' do
    it 'returns forbidden when regular admin tries to create' do
      login_as(admin, scope: :user)
      post '/api/admin/admins', params: { email: 'new@test.com', role: 'ADMIN' }

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json['error']).to include('Super Admins')

      logout(:user)
    end

    it 'creates a new admin with email only' do
      post '/api/admin/admins', params: {
        email: 'new@test.com',
        role: 'ADMIN'
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['id']).to be_present

      new_admin = User.find(json['data']['id'])
      expect(new_admin.email).to eq('new@test.com')
      expect(new_admin.role).to eq('ADMIN')
      expect(new_admin.name).to be_nil
    end

    it 'creates a new admin with email and name' do
      post '/api/admin/admins', params: {
        email: 'new@test.com',
        name: 'New Admin',
        role: 'ADMIN'
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      new_admin = User.find(json['data']['id'])
      expect(new_admin.email).to eq('new@test.com')
      expect(new_admin.name).to eq('New Admin')
    end

    it 'creates a superadmin when role is SUPERADMIN' do
      post '/api/admin/admins', params: {
        email: 'newsuper@test.com',
        role: 'SUPERADMIN'
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      new_admin = User.find(json['data']['id'])
      expect(new_admin.role).to eq('SUPERADMIN')
    end

    it 'returns error when email is missing' do
      post '/api/admin/admins', params: { role: 'ADMIN' }

      expect(response).to have_http_status(:bad_request)
    end

    it 'returns error when email is duplicate' do
      post '/api/admin/admins', params: {
        email: 'admin@test.com',
        role: 'ADMIN'
      }

      expect(response).to have_http_status(:bad_request)
      json = JSON.parse(response.body)
      expect(json['error']).to include('Email')
    end

    it 'defaults to ADMIN when role is invalid' do
      post '/api/admin/admins', params: {
        email: 'new@test.com',
        role: 'INVALID'
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      new_admin = User.find(json['data']['id'])
      expect(new_admin.role).to eq('ADMIN')
    end

    it 'defaults to ADMIN role when role is missing' do
      post '/api/admin/admins', params: {
        email: 'new@test.com'
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      new_admin = User.find(json['data']['id'])
      expect(new_admin.role).to eq('ADMIN')
    end
  end

  describe 'PATCH /api/admin/admins/:id' do
    it 'updates admin email, name, and role' do
      patch "/api/admin/admins/#{admin.id}", params: {
        email: 'updated@test.com',
        name: 'Updated Name',
        role: 'SUPERADMIN'
      }

      expect(response).to have_http_status(:no_content)

      admin.reload
      expect(admin.email).to eq('updated@test.com')
      expect(admin.name).to eq('Updated Name')
      expect(admin.role).to eq('SUPERADMIN')
    end

    it 'allows updating name to empty string' do
      patch "/api/admin/admins/#{admin.id}", params: {
        email: admin.email,
        name: '',
        role: admin.role
      }

      expect(response).to have_http_status(:no_content)
      admin.reload
      expect(admin.name).to eq('')
    end

    it 'returns error when admin not found' do
      patch '/api/admin/admins/nonexistent', params: {
        email: 'test@test.com',
        role: 'ADMIN'
      }

      expect(response).to have_http_status(:not_found)
    end

    it 'returns error when email is duplicate' do
      other_admin = User.create!(email: 'other@test.com', role: 'ADMIN', provider: 'google_oauth2', uid: 'other')

      patch "/api/admin/admins/#{admin.id}", params: {
        email: 'other@test.com',
        role: 'ADMIN'
      }

      expect(response).to have_http_status(:bad_request)
    end

    it 'keeps existing role when role is invalid' do
      patch "/api/admin/admins/#{admin.id}", params: {
        email: admin.email,
        role: 'INVALID'
      }

      expect(response).to have_http_status(:no_content)
      admin.reload
      expect(admin.role).to eq('ADMIN')
    end
  end

  describe 'DELETE /api/admin/admins/:id' do
    it 'deletes an admin' do
      admin_id = admin.id

      delete "/api/admin/admins/#{admin_id}"

      expect(response).to have_http_status(:no_content)
      expect(User.find_by(id: admin_id)).to be_nil
    end

    it 'returns error when admin not found' do
      delete '/api/admin/admins/nonexistent'

      expect(response).to have_http_status(:not_found)
    end

    it 'prevents deleting yourself' do
      delete "/api/admin/admins/#{superadmin.id}"

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json['error']).to include('No puedes eliminar tu propia cuenta')
    end
  end
end

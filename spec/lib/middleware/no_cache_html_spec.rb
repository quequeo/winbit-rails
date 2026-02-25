# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Middleware::NoCacheHtml do
  let(:app) { proc { [200, { 'Content-Type' => 'text/html' }, ['body']] } }
  let(:middleware) { described_class.new(app) }

  it 'adds Cache-Control: no-store for text/html responses' do
    status, headers, body = middleware.call({})

    expect(status).to eq(200)
    expect(headers['Cache-Control']).to eq('no-store')
    expect(headers['Content-Type']).to eq('text/html')
  end

  it 'does not add Cache-Control for non-HTML responses' do
    json_app = proc { [200, { 'Content-Type' => 'application/json' }, ['{}']] }
    mw = described_class.new(json_app)

    _status, headers, _body = mw.call({})

    expect(headers['Cache-Control']).to be_nil
  end

  it 'handles Content-Type with charset' do
    app_with_charset = proc { [200, { 'Content-Type' => 'text/html; charset=utf-8' }, ['body']] }
    mw = described_class.new(app_with_charset)

    _status, headers, _body = mw.call({})

    expect(headers['Cache-Control']).to eq('no-store')
  end

  it 'handles lowercase content-type header' do
    app_lower = proc { [200, { 'content-type' => 'text/html' }, ['body']] }
    mw = described_class.new(app_lower)

    _status, headers, _body = mw.call({})

    expect(headers['Cache-Control']).to eq('no-store')
  end
end

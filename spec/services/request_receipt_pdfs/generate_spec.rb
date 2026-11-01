# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RequestReceiptPdfs::Generate do
  let(:investor) { Investor.create!(email: 'gen-receipt@example.com', name: 'Lisandro Filardi', status: 'ACTIVE') }
  let(:req) do
    InvestorRequest.create!(
      investor: investor, request_type: 'WITHDRAWAL', method: 'USDT', amount: 100,
      network: 'TRC20', wallet_address: 'TXyz', status: 'APPROVED', operation_number: 'R-2026-0142', processed_at: Time.zone.local(2026, 10, 9, 19)
    )
  end

  it 'renders the template and stores a PDF, replacing any previous one' do
    allow(Grover).to receive(:new).and_wrap_original do |_m, html|
      expect(html).to include('Comprobante de retiro', 'Lisandro Filardi', 'R-2026-0142', 'USD 4.637,02', '100,00 USDT')
      instance_double(Grover, to_pdf: '%PDF-1.4 fake')
    end
    allow(InvestorMonthlyReportPdfs::EnsureChromeInstalled).to receive(:call)

    first = described_class.call(request: req, balance_after: '4637.02')
    second = described_class.call(request: req, balance_after: '4637.02')

    expect(second.id).to eq(first.id)
    expect(RequestReceiptPdf.where(request_id: req.id).count).to eq(1)
    expect(second.original_filename).to eq('Winbit_Comprobante_Retiro_R-2026-0142.pdf')
  end

  it 'refuses non-approved requests' do
    req.update!(status: 'PENDING')
    expect { described_class.call(request: req) }.to raise_error(StandardError, /aprobadas/)
  end
end

# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvestorMonthlyReportPdfs::EnsureChromeInstalled do
  before do
    described_class.instance_variable_set(:@installed, nil)
  end

  after do
    described_class.instance_variable_set(:@installed, nil)
  end

  it 'does not shell out when PUPPETEER_EXECUTABLE_PATH is set (a system Chrome is configured)' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('PUPPETEER_EXECUTABLE_PATH').and_return('/usr/bin/google-chrome-stable')

    expect(described_class).not_to receive(:system)
    described_class.call
  end

  it 'does not shell out when Chrome is already present under PUPPETEER_CACHE_DIR' do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'chrome', 'linux-1.0.0', 'chrome-linux64'))
      FileUtils.touch(File.join(dir, 'chrome', 'linux-1.0.0', 'chrome-linux64', 'chrome'))

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('PUPPETEER_EXECUTABLE_PATH').and_return(nil)
      allow(ENV).to receive(:[]).with('PUPPETEER_CACHE_DIR').and_return(dir)

      expect(described_class).not_to receive(:system)
      described_class.call
    end
  end

  it 'installs Chrome once and memoizes across subsequent calls' do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('PUPPETEER_EXECUTABLE_PATH').and_return(nil)
    allow(ENV).to receive(:[]).with('PUPPETEER_CACHE_DIR').and_return(nil)

    expect(described_class).to receive(:system)
      .with('npx', 'puppeteer', 'browsers', 'install', 'chrome', exception: true)
      .once.and_return(true)

    described_class.call
    described_class.call
  end
end

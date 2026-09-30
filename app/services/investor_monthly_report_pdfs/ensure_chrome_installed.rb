# frozen_string_literal: true

module InvestorMonthlyReportPdfs
  # Makes sure Puppeteer's Chrome is on disk before Grover tries to launch it.
  #
  # Installing Chrome during the Heroku build (heroku-postbuild, then
  # bin/post_compile) doesn't work on this app: the build log shows the
  # download succeeding both ways, but neither survives into the deployed
  # slug (confirmed with real deploys each time - see
  # config/initializers/grover.rb). Installing here instead, at runtime on
  # first use, sidesteps that entirely - PUPPETEER_CACHE_DIR just needs to
  # be a path this dyno's own filesystem can write to, which /app is at
  # runtime (unlike during the build). Costs one ~15s download the first
  # time a PDF is generated after a dyno boots; free after that.
  class EnsureChromeInstalled
    MUTEX = Mutex.new

    def self.call
      return if @installed

      MUTEX.synchronize do
        return if @installed

        # A configured system Chrome (PUPPETEER_EXECUTABLE_PATH, e.g. CI's
        # runner-provided browser) means there's nothing to install.
        @installed = ENV['PUPPETEER_EXECUTABLE_PATH'].present? ||
                     chrome_present? ||
                     system('npx', 'puppeteer', 'browsers', 'install', 'chrome', exception: true)
      end
    end

    def self.chrome_present?
      cache_dir = ENV['PUPPETEER_CACHE_DIR'].presence
      return false unless cache_dir && Dir.exist?(cache_dir)

      Dir.glob(File.join(cache_dir, '**', 'chrome{,.exe}')).any?
    end
  end
end

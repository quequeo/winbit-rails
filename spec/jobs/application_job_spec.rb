require 'rails_helper'

RSpec.describe ApplicationJob do
  it 'inherits from ActiveJob::Base' do
    expect(described_class < ActiveJob::Base).to eq(true)
  end
end

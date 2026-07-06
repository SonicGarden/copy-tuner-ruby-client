require 'spec_helper'

describe CopyTunerClient do
  before do
    allow(described_class.configuration).to receive_messages(cache: 'cache', client: 'client')
  end

  it 'delegates cache to the configuration object' do
    expect(described_class.configuration).to receive(:cache).once
    expect(described_class.cache).to eq('cache')
  end

  it 'delegates client to the configuration object' do
    expect(described_class.configuration).to receive(:client).once
    expect(described_class.client).to eq('client')
  end
end

require 'spec_helper'

describe CopyTunerClient do
  before do
    allow(described_class.configuration).to receive_messages(cache: 'cache', client: 'client')
  end

  it 'delegates cache to the configuration object' do
    expect(described_class.cache).to eq('cache')
    expect(described_class.configuration).to have_received(:cache).once
  end

  it 'delegates client to the configuration object' do
    expect(described_class.client).to eq('client')
    expect(described_class.configuration).to have_received(:client).once
  end
end

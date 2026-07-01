require 'spec_helper'
require 'copy_tuner_client/copyray'

describe CopyTunerClient::Copyray do
  describe '.augment_template' do
    subject { CopyTunerClient::Copyray.augment_template(source, key) }

    let(:key) { 'en.test.key' }

    before do
      CopyTunerClient.configure do |configuration|
        configuration.project_id = 1
        configuration.client = FakeClient.new
      end
    end

    context 'when the source is html_safe (e.g. _html key)' do
      let(:source) { FakeHtmlSafeString.new('<b>Hello</b>').html_safe }

      it 'keeps the html_safe flag so the translation is not re-escaped' do
        expect(subject).to be_html_safe
      end

      it 'prepends the visible marker token without escaping' do
        expect(subject).to eq '⟦CT:en.test.key⟧<b>Hello</b>'
      end
    end

    context 'when the source is plain text (not html_safe)' do
      let(:source) { FakeHtmlSafeString.new('Hello & <World>') }

      it 'prepends the marker but keeps the source non html_safe so ActionView still escapes the body' do
        expect(subject).to eq '⟦CT:en.test.key⟧Hello & <World>'
        expect(subject).not_to be_html_safe
      end
    end

    context 'when the key matches local_first_key_regexp' do
      let(:key) { 'views.foo' }

      before { CopyTunerClient.configuration.local_first_key_regexp = /\Aviews\./ }

      it 'does not inject the marker into a plain source' do
        expect(CopyTunerClient::Copyray.augment_template('Hello', key)).to eq 'Hello'
      end

      it 'does not inject the marker into an html_safe source' do
        expect(CopyTunerClient::Copyray.augment_template('Hello'.html_safe, key)).to eq 'Hello'
      end
    end
  end
end

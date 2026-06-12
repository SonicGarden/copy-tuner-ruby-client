require 'spec_helper'
require 'copy_tuner_client/copyray'

describe CopyTunerClient::Copyray do
  describe '.augment_template' do
    subject { CopyTunerClient::Copyray.augment_template(source, key) }

    let(:key) { 'en.test.key' }

    shared_examples 'Not escaped' do
      it { is_expected.to be_html_safe }
      it { is_expected.to eq "<!--COPYRAY #{key}--><b>Hello</b>" }
    end

    context 'html_escape option is false' do
      before do
        CopyTunerClient.configure do |configuration|
          configuration.html_escape = false
          configuration.client = FakeClient.new
        end
      end

      context 'string not marked as html safe' do
        let(:source) { FakeHtmlSafeString.new('<b>Hello</b>') }

        it_behaves_like 'Not escaped'
      end

      context 'string marked as html safe' do
        let(:source) { FakeHtmlSafeString.new('<b>Hello</b>').html_safe }

        it_behaves_like 'Not escaped'
      end
    end

    context 'html_escape option is true' do
      before do
        CopyTunerClient.configure do |configuration|
          configuration.html_escape = true
          configuration.client = FakeClient.new
        end
      end

      context 'string not marked as html safe' do
        let(:source) { FakeHtmlSafeString.new('<b>Hello</b>') }

        it { is_expected.to be_html_safe }
        it { is_expected.to eq "<!--COPYRAY #{key}-->&lt;b&gt;Hello&lt;/b&gt;" }
      end

      context 'string marked as html safe' do
        let(:source) { FakeHtmlSafeString.new('<b>Hello</b>').html_safe }

        it_behaves_like 'Not escaped'
      end
    end

    context 'when the key matches local_first_key_regexp' do
      let(:source) { 'Hello' }
      let(:key) { 'views.foo' }

      before { CopyTunerClient.configuration.local_first_key_regexp = /\Aviews\./ }

      it 'does not inject the overlay marker' do
        is_expected.to eq 'Hello'
      end
    end

    context 'when copyray_marker_type is :subliminal' do
      before { CopyTunerClient.configuration.copyray_marker_type = :subliminal }
      after { CopyTunerClient.configuration.copyray_marker_type = :comment }

      def leading_marker(str)
        str[/\A[‌‍]+/]
      end

      context 'string not marked as html safe' do
        let(:source) { FakeHtmlSafeString.new('<b>Hello</b>') }

        it 'prepends the invisible marker without forcing html_safe (Rails standard compatible)' do
          is_expected.not_to be_html_safe
          expect(CopyTunerClient::Subliminal.remove(subject)).to eq '<b>Hello</b>'
          expect(CopyTunerClient::Subliminal.decode(leading_marker(subject))).to eq key
        end
      end

      context 'string marked as html safe' do
        let(:source) { FakeHtmlSafeString.new('<b>Hello</b>').html_safe }

        it 'prepends the invisible marker and preserves html_safe' do
          is_expected.to be_html_safe
          expect(CopyTunerClient::Subliminal.remove(subject)).to eq '<b>Hello</b>'
          expect(CopyTunerClient::Subliminal.decode(leading_marker(subject))).to eq key
        end
      end
    end
  end
end

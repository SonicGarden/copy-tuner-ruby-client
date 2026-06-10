require 'spec_helper'
require 'copy_tuner_client/helper_extension'
require 'copy_tuner_client/copyray'

describe CopyTunerClient::HelperExtension do
  module KeywordArgumentsHelper
    def translate(key, **options)
      "Hello, #{options[:name]}"
    end

    def controller
      nil
    end
  end

  class KeywordArgumentsView
    include KeywordArgumentsHelper
  end

  CopyTunerClient::HelperExtension.hook_translation_helper(KeywordArgumentsHelper, middleware_enabled: true)

  it 'works with keyword argument method' do
    view = KeywordArgumentsView.new
    expect(view.translate('some.key', name: 'World')).to eq '<!--COPYRAY some.key-->Hello, World'
  end

  it 'does not inject the overlay marker for a local_first key' do
    CopyTunerClient.configuration.local_first_key_regexp = /\Aviews\./
    view = KeywordArgumentsView.new
    expect(view.translate('views.foo', name: 'World')).to eq 'Hello, World'
  end

  it 'injects the invisible subliminal marker in subliminal mode' do
    CopyTunerClient.configuration.copyray_marker_type = :subliminal
    view = KeywordArgumentsView.new
    result = view.translate('some.key', name: 'World')
    expect(CopyTunerClient::Subliminal.remove(result)).to eq 'Hello, World'
    expect(CopyTunerClient::Subliminal.decode(result[/\A[‌‍]+/])).to eq 'some.key'
  ensure
    CopyTunerClient.configuration.copyray_marker_type = :comment
  end
end

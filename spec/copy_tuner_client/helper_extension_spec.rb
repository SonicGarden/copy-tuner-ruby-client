require 'spec_helper'
require 'copy_tuner_client/helper_extension'
require 'copy_tuner_client/copyray'

describe CopyTunerClient::HelperExtension do
  module KeywordArgumentsHelper
    def translate(key, **options)
      "Hello, #{options[:name]}"
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
end

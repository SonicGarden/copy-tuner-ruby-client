CopyTuner Client
=================

[![Build Status](https://travis-ci.org/SonicGarden/copy-tuner-ruby-client.svg?branch=master)](https://travis-ci.org/SonicGarden/copy-tuner-ruby-client)

## Getting started

Add it to your Gemfile

```
gem 'copy_tuner_client'
```

Create config/initializers/copy_tuner.rb

```
CopyTunerClient.configure do |config|
  config.api_key = 'YOUR-API-KEY'
  config.host = 'COPY-TUNER-HOST-NAME'
  
  # I18n key and messages will be sent to server if the locale matches
  config.locales = [:ja, :en]
end
```

## CopyTunerの翻訳ファイルをymlとして出力する

該当のRailsプロジェクトで下記のrakeを実行する

```
bundle exec rake copy_tuner:export
```

これで、`config/locales/copy_tuner.yml` に翻訳ファイルが作成されます。

Development
=================

## Spec

### default spec

    $ bundle exec rake

### Appraisal for Multi Version Rails spec

    $ bundle exec appraisal install
    $ bundle exec rake appraisal

## release gem

    $ bundle exec rake build      # build gem to pkg/ dir
    $ bundle exec rake install    # install to local gem
    $ bundle exec rake release    # release gem to rubygems.org


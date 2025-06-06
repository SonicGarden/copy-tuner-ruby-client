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
  config.project_id = 77
  config.host = 'COPY-TUNER-HOST-NAME'
  config.html_escape = true

  # I18n keys and messages will be sent to server if the locale matches
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

## クライアント用コード

`src`以下を編集してください。
`app/assets/*`を直接編集したらダメよ！

```
$ yarn dev   # 開発時
$ yarn build   # ビルド
```


## Spec

### default spec

```
$ bundle exec rspec
```

## release gem

    $ bundle exec rake build      # build gem to pkg/ dir
    $ bundle exec rake install    # install to local gem
    $ bundle exec rake release    # release gem to rubygems.org

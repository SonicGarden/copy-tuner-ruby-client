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

## 特定のキーをローカル YAML 優先にする（段階移行）

`config.local_first_key_regexp` を設定すると、**locale を除いたキー**（例 `views.foo.bar`）がその正規表現にマッチした場合、CopyTuner サーバのキャッシュをスキップして、ローカルの `config/locales/*.yml`（`I18n::Backend::Simple`）を優先的に参照します。

```ruby
CopyTunerClient.configure do |config|
  # ...
  # views.* で始まるキーはローカル YAML を優先する
  config.local_first_key_regexp = /\Aviews\./
end
```

CopyTuner で一元管理している翻訳を、`views.*` のような単位で段階的にローカル YAML へ移行するためのオプションです。

- マッチしたキーは CopyTuner キャッシュを一切参照せず、ローカル YAML のみを引きます（完全分離）。
- ローカル YAML にも存在しない場合は未訳（`nil` / MissingTranslation）となります。CopyTuner へのフォールバックや新規キーのアップロードは行いません。これにより移行漏れを未訳として検知できます。
- マッチしたキーには、ビューヘルパー（`t` / `translate`）および SimpleForm のラベルで CopyRay オーバーレイマーカー（`<!--COPYRAY key-->`）を注入しません。これらのキーは CopyTuner 上で編集できないため、編集可能だと誤認させないためです。

`exclude_key_regexp` との違い:

| オプション | 対象 | 作用するタイミング |
| --- | --- | --- |
| `exclude_key_regexp` | locale 付きキー（例 `ja.views.foo`） | アップロード時（CopyTuner への送信を抑止） |
| `local_first_key_regexp` | locale を除いたキー（例 `views.foo`） | 読み込み時（lookup の優先順位） |

## Claude Code スキル

`skills/copy-tuner/` に Claude Code 向けのスキルが含まれています。

### copy-tuner スキル

i18n キーの操作を支援するスキルです。翻訳キーの検索・登録・確認などの依頼に自動的に使用されます。

```
gh skill install SonicGarden/copy-tuner-ruby-client copy-tuner --scope project
```

詳細: [skills/copy-tuner/SKILL.md](skills/copy-tuner/SKILL.md)

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

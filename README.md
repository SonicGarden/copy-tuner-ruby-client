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

### Rails 標準の数値フォーマットキーは常にローカル優先（組み込み）

`local_first_key_regexp` の設定有無にかかわらず、以下の Rails 標準キーは**常にローカル YAML 優先**になります（CopyTuner をバイパス）。

- `number.format` / `number.currency.format` / `number.percentage.format` / `number.human.format`（およびその配下）

これらは `precision`（整数）や `significant` / `strip_insignificant_zeros`（真偽値）といった非文字列値を含みます。CopyTuner は文字列値しか保持できないため、経由するとこれらが欠落し、`number_to_currency` などが意図しない表示（小数桁数や記号の崩れ）になります。これを防ぐため gem 側で固定的にローカル優先にしています。

アプリ独自の `number.*` キー（例 `number.gift_amount`）は対象外で、従来どおり CopyTuner で管理できます。

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

Node.js と pnpm は [mise](https://mise.jdx.dev/) で管理しています（`mise install` でセットアップ）。

```
$ pnpm install   # 依存インストール
$ pnpm dev       # 開発時
$ pnpm build     # ビルド
$ pnpm check     # Lint + Format（Biome）
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

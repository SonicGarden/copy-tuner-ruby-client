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

## Middleware の挿入位置

CopyTuner は開発環境で `RequestSync` / `CopyrayMiddleware` を Rack の middleware スタックに挿入します。`RequestSync` はリクエスト毎に CopyTuner サーバと同期し、`CopyrayMiddleware` はページ内のマーカー（`⟦CT:key⟧`）を除去・変換します。

挿入位置は自動で決まるため、通常は設定不要です。Devise（Warden）を使っているアプリでは `Warden::Manager` の直前、それ以外の環境ではスタック末尾に挿入されます。

Devise 併用時に Warden の直前へ寄せるのは `throw :warden` の挙動に対応するためです。`throw :warden` は `Warden::Manager` の `catch(:warden)` までスタックを巻き戻すため、CopyTuner の middleware が Warden より内側にあると、認証エラー時のレスポンス（`Devise::FailureApp` が返す HTML）を受け取れず、Copyray のマーカーがページに残ってしまいます。

位置を変えたい場合は `config.middleware_position` に `{ before: SomeMiddleware }` または `{ after: SomeMiddleware }` を指定すると、このデフォルトを上書きできます。

```ruby
CopyTunerClient.configure do |config|
  # ...
  config.middleware_position = { after: Rack::Runtime }
end
```

指定した middleware がスタックに存在しない場合、Rails の起動時に例外（`No such middleware to insert before: ...` / `... insert after: ...`）が発生します。

## Claude Code スキル

`skills/` 以下に Claude Code 向けのスキルが含まれています。

```
gh skill install SonicGarden/copy-tuner-ruby-client <スキル名> --scope project
```

### copy-tuner スキル

i18n キーの操作を支援するスキルです。翻訳キーの検索・登録・確認などの依頼に自動的に使用されます。

詳細: [skills/copy-tuner/SKILL.md](skills/copy-tuner/SKILL.md)

### copy-tuner-to-locales-migrate-prefix スキル

copy_tuner が集中管理する i18n キーを、prefix（正規表現）単位で `config/locales` のローカル YAML 管理へ移行するスキルです。gem は残したまま特定 prefix だけをローカル化する「部分ローカル化」と、全 prefix を移して完全撤去する「全移行」の両方に使えます。明示的に呼び出したときのみ動作します。

詳細: [skills/copy-tuner-to-locales-migrate-prefix/SKILL.md](skills/copy-tuner-to-locales-migrate-prefix/SKILL.md)

### copy-tuner-to-locales-cleanup スキル

`copy-tuner-to-locales-migrate-prefix` で全 prefix の移行が完了した後に、gem・初期化子・CI・deploy・ドキュメント・MCP 設定を一括撤去し、copy_tuner 依存を完全に取り除くスキルです。明示的に呼び出したときのみ動作します。

詳細: [skills/copy-tuner-to-locales-cleanup/SKILL.md](skills/copy-tuner-to-locales-cleanup/SKILL.md)

### copy-tuner-to-t-migrate スキル

copy_tuner_client v2.0.0 で削除された独自ヘルパー `tt` の呼び出しを、Rails 標準の `t`（`translate`）へ置換するスキルです。機械的に安全な箇所は一括変換し、文字列加工や `label` の第一引数に渡している箇所は 1 件ずつ確認しながら置換します。破壊的な一括書き換えを含むため、明示的に呼び出したときのみ動作します。

詳細: [skills/copy-tuner-to-t-migrate/SKILL.md](skills/copy-tuner-to-t-migrate/SKILL.md)

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

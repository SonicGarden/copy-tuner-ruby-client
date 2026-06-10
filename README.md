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
- マッチしたキーには、ビューヘルパー（`t` / `translate`）および SimpleForm のラベルで CopyRay オーバーレイマーカー（[後述](#copyray-オーバーレイマーカー方式copyray_marker_type)）を注入しません。これらのキーは CopyTuner 上で編集できないため、編集可能だと誤認させないためです。

`exclude_key_regexp` との違い:

| オプション | 対象 | 作用するタイミング |
| --- | --- | --- |
| `exclude_key_regexp` | locale 付きキー（例 `ja.views.foo`） | アップロード時（CopyTuner への送信を抑止） |
| `local_first_key_regexp` | locale を除いたキー（例 `views.foo`） | 読み込み時（lookup の優先順位） |

### `exclude_key_regexp` は非推奨です

`exclude_key_regexp` は **非推奨**です（将来のリリースで削除予定）。設定すると deprecation 警告が出ます。代わりに `local_first_key_regexp` を使ってください。

```ruby
# Before（非推奨）
config.exclude_key_regexp = /\Aja\.views\./

# After: locale プレフィックス（ja.）を外して指定する
config.local_first_key_regexp = /\Aviews\./
```

移行時の注意:

- 対象キーの形式が異なります。`exclude_key_regexp` は **locale 付き**（`ja.views.foo`）、`local_first_key_regexp` は **locale を除いた**形式（`views.foo`）でマッチします。正規表現から locale プレフィックスを外してください。
- 挙動も少し変わります。`exclude_key_regexp` はアップロードを抑止するだけで lookup 時は CopyTuner キャッシュを参照し続けますが、`local_first_key_regexp` は lookup 時に CopyTuner キャッシュをスキップしてローカル YAML を優先します（完全分離）。ローカル管理へ移行する用途では `local_first_key_regexp` のほうが適切です。

## CopyRay オーバーレイマーカー方式（`copyray_marker_type`）

開発環境では、ブラウザ上で翻訳テキストにオーバーレイを表示し、クリックで CopyTuner の編集画面を開けます（`Ctrl`/`Cmd` + `Shift` + `K`）。このとき、ビューヘルパー（`t` / `translate`）および SimpleForm のラベルの出力に、ブラウザ側がキーを特定するためのマーカーを埋め込みます。

`config.copyray_marker_type` でマーカーの方式を選べます。

```ruby
CopyTunerClient.configure do |config|
  # :comment（デフォルト） … HTML コメント方式
  # :subliminal           … 不可視 Unicode 文字方式
  config.copyray_marker_type = :comment
end
```

| 方式 | マーカー | 出力の `html_safe` |
| --- | --- | --- |
| `:comment`（デフォルト） | `<!--COPYRAY key-->message` | **常に** `html_safe` になる |
| `:subliminal` | 不可視文字（ZWNJ/ZWJ）でキーを前置 | 元の出力の `html_safe` 状態を維持（Rails 標準互換） |

### `:subliminal` 方式について

`:comment` 方式は HTML コメント（`<!-- -->`）を含むため、ヘルパー出力を常に `html_safe` にする必要があり、Rails 標準の `translate` ヘルパー（`_html` 終端キー以外は `html_safe` にしない）と挙動が食い違います。

`:subliminal` 方式は HTML 特殊文字を含まない不可視文字でマーカーを表現するため、**元の `html_safe` 状態をそのまま維持**でき、Rails 標準と概ね互換になります。`_html` キーの扱いやエスケープ挙動を標準に揃えたい場合に有効です。

#### 既知の制約とマーカー無しヘルパー（`tt`）

`:subliminal` 方式では、マーカーは**ビューヘルパー / SimpleForm ラベルの出力**にのみ付きます（フレームワーク内部の `I18n.t`・`l(date)`・`human_attribute_name` などには付きません）。ただし、ヘルパー出力を以下のような用途に使う場合、不可視文字が混入して問題になることがあります。

- `truncate` など文字数で切り詰める処理（先頭マーカーが字数を消費し、可視テキストが出ないことがある）
- フォームの value / hidden field / select の value として送信する値
- メールの件名・本文、JSON/API レスポンスなど、表示以外で利用する文字列

このような箇所では、マーカーを付けない翻訳ヘルパー `tt` を使ってください（`t` の代わりに `tt` を呼ぶだけです）。`tt` は CopyRay マーカーを一切付与しません（`:comment` 方式でも同様）。

```ruby
truncate(tt('.long_description'), length: 50)
```

> いずれの方式も、マーカーが付くのは開発（`development_environments`）でミドルウェアが有効なときだけです。本番では付きません。

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

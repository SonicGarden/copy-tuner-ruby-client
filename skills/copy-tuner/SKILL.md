---
name: copy-tuner
description: "このプロジェクトの i18n キー（翻訳）の参照・追加・更新・削除を行うスキル。i18n / 翻訳 / ロケール / `t` / `tt` / 翻訳キーに関わる操作のとき、および `config/locales` ディレクトリや `.yml` 翻訳ファイルを読む・参照する・編集するときは必ず使用すること。翻訳は原則 copy_tuner サーバで管理されており（一部キーのみ config/locales 管理）、素朴に config/locales を読むだけでは大半の翻訳が見つからず誤った判断をするため、必ずこのスキルの手順に従う。"
license: MIT
---

# copy_tuner スキル

このプロジェクトの i18n は原則 **copy_tuner** サーバで管理し、MCP ツールで操作する。
例外として `local_first_key_regexp` にマッチするキーだけは `config/locales/*.yml` で管理される。
**どちらの管理かを最初に判別する。**

## キーの管理場所の判別

1. `config/initializers/copy_tuner.rb` の `local_first_key_regexp` を確認する（未設定なら全キー copy_tuner）。
2. 対象キーから **locale を除いた形**（`ja.views.foo` → `views.foo`）がその正規表現にマッチするか見る。

| 判別 | 管理場所 | 操作 |
|---|---|---|
| マッチする | config/locales（copy_tuner と完全分離） | `config/locales/*.yml` を Read / Edit |
| マッチしない・未設定 | copy_tuner | MCP ツール（下記） |

**config/locales 管理キーの落とし穴:**
- copy_tuner には存在しないので、MCP ツールで探しても見つからない。`config/locales` を見ること。
- copy_tuner に登録しても lookup でバイパスされ無効。必ず `.yml` 側に書く。
- ja が無ければ未訳（`nil`）。copy_tuner にフォールバックしない（移行漏れを顕在化させる設計）。
- prefix 単位の一括移行は別作業。必要なら `skills/copy-tuner-to-locales-migrate-prefix/` を使う。

## copy_tuner MCP ツール

| やりたいこと | ツール |
|---|---|
| キー名（一部）から翻訳を調べる | `search_key`（引数は英語キーワード） |
| 画面テキストからキーを逆引き | `search_translations` |
| 新しいキーを登録する | `create_i18n_key` |
| 既存キーの翻訳を更新する | `get_edit_url`（ブラウザ編集） |
| 使用中ロケールを確認 | `get_locales` |

## 新規キー登録

1. `search_key` で関連キーを検索し、既存の命名パターンに合わせる（例: `search_key("move_out")`）。
2. ja は必須。他は `get_locales` で確認し、存在するロケール分を登録する。

## 不要なキーの処理

削除せず `config/initializers/copy_tuner.rb` の `ignored_keys` に追加する。
一定期間どこからも参照されていないことを確認してから手動削除する。

## `t` と `tt` の使い分け

**HTML 要素の属性値には `tt` を使う**（それ以外の通常出力は `t`）。`tt` は copy_tuner_client gem の
`HelperExtension` が提供するエイリアス。`t` は CopyTuner の都合で HTML コメント (`<!-- ... -->`) を
埋め込むため、属性値に入ると表示崩れや動作不良の原因になる。

```erb
<div title="<%= tt('views.tooltips.help_text') %>">...</div>
<h1><%= t('views.simulation.show.title') %></h1>
```

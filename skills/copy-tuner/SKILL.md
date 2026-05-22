---
name: copy-tuner
description: copy_tuner を使った i18n キーの操作スキル。「翻訳キーを調べて」「i18nキーを追加して」「このテキストのキーは？」「i18nキーを探して」「翻訳を確認して」「copy_tunerで調べて」のような依頼に必ず使用する。新しい翻訳キーが必要な実装時、既存キーを参照する時、不要になったキーを処理する時にも積極的に使用する。
license: MIT
---

# copy_tuner スキル

このプロジェクトの i18n は `config/locales` ではなく **copy_tuner** で管理している。
キーの参照・登録・更新は copy_tuner MCP ツールで行う。

## 操作の判断

| やりたいこと | 使うツール |
|---|---|
| キー名（または一部）から翻訳を調べる | `search_key` |
| 画面テキストからキーを逆引き | `search_translations` |
| 新しいキーを登録する | `create_i18n_key` |
| 既存キーの翻訳を更新する | `get_edit_url` でブラウザ編集 |
| 使用中ロケールを確認 | `get_locales` |

> **使い分け**: キー名の一部（ドット区切りの名前空間など）が分かっているなら `search_key`（引数は英語のキーワード）。テキスト（日本語・英語の表示文言）しか分からないなら `search_translations`。命名パターンを調べたいときは両方試す。

## 新規キー登録のフロー

1. `search_key` で機能名・画面名を英語キーワードで検索し、命名パターンを把握する（例: `search_key("move_out")` で退去関連のキー名の構造を確認する）
2. パターンに合わせたキー名を決める
3. ja は必須。他に必要なロケールは `get_locales` で確認し、存在するロケール分を翻訳して登録する
4. コード内で翻訳キーを使用する（`t` と `tt` の使い分けは「I18nメソッドの使い分け」セクション参照）

## 不要なキーの処理

コード削除等で不要になったキーは削除せず `config/initializers/copy_tuner.rb` の `ignored_keys` に追加する。
一定期間どこからも参照されていないことを確認してから手動削除する。

## I18nメソッドの使い分け

- **`t`メソッド**: 通常のテキスト出力に使用
- **`tt`メソッド**: **HTML要素の属性値**に使用（必須）。copy_tuner_client gem の `HelperExtension` が提供するエイリアス。

**理由**: CopyTunerの影響で `t` はHTMLコメント (`<!-- ... -->`) を埋め込みます。属性値に含まれると意図しない表示や動作不良の原因となります。

```erb
<div title="<%= tt('views.tooltips.help_text') %>">...</div>
<input placeholder="<%= tt('views.forms.enter_name') %>">
<h1><%= t('views.simulation.show.title') %></h1>
```

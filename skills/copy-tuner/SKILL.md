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
| マッチしない・未設定 | copy_tuner | **MCP ツール経由でのみ探す**（下記） |

**copy_tuner 管理のキーは必ず MCP ツール経由で探すこと。** ローカルの `.yml` を grep して見つけたつもりになってはならない。

**例外（gem 組み込み・設定不要で常に config/locales 管理）:** Rails 標準の `number.format` /
`number.currency.format` / `number.percentage.format` / `number.human.format`（およびその配下）。
`precision` 等の非文字列値を含み copy_tuner では正しく扱えないため、gem が常にバイパスする。
これらは `config/locales/*.yml` を見る・編集すること（アプリ独自の `number.gift_amount` 等は対象外で通常どおり copy_tuner）。

**`config/locales` 以外の export 済み yml は参照禁止:**
環境によっては copy_tuner から export したキャッシュ用の `.yml`（`config/locales` 配下以外、例: アプリ直下や `tmp/`、`db/` などに置かれた export ファイル）が存在することがある。
これらは古いスナップショットであり権威ある情報源ではない。**読んで判断材料にしてはならない。** copy_tuner 管理キーは常に MCP ツールで最新を確認する。

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
| 既存キーのドラフト訳を更新する | `update_i18n_key` |
| 既存キーの翻訳を更新する（ブラウザ） | `get_edit_url` |
| 使用中ロケールを確認 | `get_locales` |

## 新規キー登録

1. `search_key` で関連キーを検索し、既存の命名パターンに合わせる（例: `search_key("move_out")`）。
2. ja は必須。他は `get_locales` で確認し、存在するロケール分を登録する。

## 既存キーの訳を更新する

`update_i18n_key` を使う。`key` と `translations`（ロケール・値のペア配列）は両方必須。

**制約**: ドラフト状態または未発行のキーのみ更新可能。発行済み（published）かどうかを事前に知る手段はなく、API にリクエストしてエラーが返るかどうかで初めてわかる。

**published キーへの対応方針**: 値を直接書き換えるのはリスクが高いため、原則として以下の手順を推奨する:
1. 新しいキーにバージョン番号を付けて登録する（例: `views.foo_v2`）→ **新規キー登録の手順に従う**
2. コード側の参照を新キーに差し替える
3. 古いキーを `config/initializers/copy_tuner.rb` の `ignored_keys` に追加する

どうしても既存キーを書き換えたい場合は `get_edit_url` でブラウザから編集する。

## 不要なキーの処理

削除せず `config/initializers/copy_tuner.rb` の `ignored_keys` に追加する。
一定期間どこからも参照されていないことを確認してから手動削除する。

## 翻訳ヘルパー（`t` / `tt`）

**通常出力・属性値ともに `t`（`translate`）を使う。** 属性値も含めて区別は不要。

**`tt` は非推奨。新規コードでは使わない。** PR #122 で存在理由を喪失し次のメジャーで削除予定。
既存の `tt` 呼び出しは原則 `t` へ置き換えてよい（属性値含め）。

## 落とし穴: 開発環境で訳文にマーカートークンが混入する

PR #122 の可視トークン方式では、development（`middleware` 有効時）の `t('key')` の戻り値は
`⟦CT:key⟧訳文本体`（記号は U+27E6 / U+27E7）のように、訳文先頭に Copyray マーカートークンが付いた
文字列になる。トークンは配信直前に `CopyrayMiddleware` → `Rewriter` が `data-copyray-key` 属性へ変換
して HTML から完全除去するため画面表示は正常だが、**ビューで訳文を文字列として加工するコードは、
除去前のトークン込み文字列に作用してしまう。**

**本番では再現しない。** 本番では `CopyrayMiddleware` 自体が登録されずマーカー注入もされないため、
戻り値は素の訳文。**開発環境だけ挙動が違う**のが見落としやすい点。

危険なコード例:

```erb
<%= truncate(t('views.foo.body')) %>   <%# ⟦CT:...⟧ 込みの長さで切られ、トークン途中で切れる／本文が短く切られる %>
<%= t('views.foo.title').length %>     <%# トークン長が加算され想定外の値になる %>
```

一般化すると、`t(...)` の戻り値を `truncate` / `length` / スライス（`[0..n]`）/ 正規表現マッチ /
文字数バリデーション等で**文字列処理する全般**が対象。

**対処**: 訳文を文字列加工する場合、マーカーを注入しない `I18n.t`（`translate` ヘルパーではなく
`I18n` モジュールを直接呼ぶ）で訳文を取得してから加工する。`I18n.t` は HelperExtension のラッパーを
通らないためトークンが付かない。

```erb
<%= truncate(I18n.t('views.foo.body')) %>
```

注意:
- `I18n.t` は partial 相対キー（先頭ドットの `t('.body')`）を解決しないので、`I18n.t('views.foo.body')`
  のように**絶対キーで書く**こと。

**このスキルでの注意**: キー追加・参照・コード差し替えを行う際、上記のように訳文を文字列加工して
いるコードを書く／触る場合はこの罠を念頭に置くこと。

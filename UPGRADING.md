# v1 から v2 へのアップグレードガイド

CopyTuner Ruby クライアント gem を **v1.5.0 系から v2.0.0** へ上げる際の移行手順です。

v2 には後方互換性に影響する変更が複数含まれます。アップグレード前に本ガイドを一読し、該当する変更にすべて対応してください。

## 変更点早見表

| 区分 | 設定 / ヘルパー | 対応 | 影響箇所 |
| --- | --- | --- | --- |
| 破壊的変更 | `config.project_id` | **必須化**。未設定だと起動時に `ArgumentError` | initializer |
| 破壊的変更 | `tt` ヘルパー | **削除**。`t`（`translate`）へ置換 | ビュー |
| 破壊的変更 | `config.html_escape` | **削除**。設定行を削除。命名規約へ移行 | initializer / キー命名 |
| 破壊的変更 | `config.exclude_key_regexp` | **削除**。`config.local_first_key_regexp` へ移行（使っている場合のみ） | initializer |
| 前提 | Ruby バージョン | **3.3 以上**が必要 | 実行環境 |
| 挙動変更 | Copyray オーバーレイ | 基本は対応不要（後述） | （カスタム処理がある場合のみ） |

---

## 前提: Ruby 3.3 以上

v2 は Ruby **3.3.0 以上**を要求します（`required_ruby_version >= 3.3.0`）。これより古い Ruby では bundle install に失敗します。先に Ruby を 3.3 以上へ更新してください。

---

## 破壊的変更

### 1. `config.project_id` が必須になりました

**何が変わったか**

`config.project_id` を設定していないと、起動時（`CopyTunerClient.configure` 実行時）に次の例外で失敗します。

```
ArgumentError: project_id is required
```

v1 では `project_id` 未設定時に `api_key` の値へフォールバックし、deprecation 警告を出していました。**v2 ではこのフォールバックを削除**したため、`project_id` の明示が必須です。

**なぜ**

`api_key` への暗黙フォールバックは挙動が分かりにくく、設定ミスを警告止まりで見逃しやすいものでした。必須化することで設定漏れを起動時に確実に検知できます。

**移行手順**

initializer に `config.project_id` を追加します。

```ruby
# config/initializers/copy_tuner.rb
CopyTunerClient.configure do |config|
  config.api_key = 'YOUR-API-KEY'
  config.project_id = 77 # ← 追加（CopyTuner サーバのプロジェクト ID）
  config.host = 'COPY-TUNER-HOST-NAME'
end
```

---

### 2. `tt` ヘルパーを削除

**何が変わったか**

`tt` ヘルパーを削除しました。呼び出しはすべて `t`（`translate`）へ置き換えてください。v2 に上げたあとビューに `tt(...)` が残っていると **`NoMethodError`（未定義ヘルパー）** になります。

**なぜ**

`tt` はもともと「Copyray マーカーを注入しない生の訳文を取る」ためのヘルパーでした。旧方式では `t('key')` の戻り値そのものにマーカーが埋め込まれ、`truncate` / `length` 等で**訳文を文字列加工する箇所**でマーカー長が混入して壊れる問題があり、その回避策が `tt` でした。

Copyray のマーカー方式刷新（後述）により、マーカー注入は戻り値ではなく middleware 側で行い HTML 配信前に完全除去するようになりました。これで通常の `t` がどこでも安全に使えるようになり、`tt` は存在理由を失って削除されました。

**移行手順**

基本は `tt(` を `t(` に置き換えるだけです。

```erb
<%# Before（v1） %>
<%= tt('.title') %>

<%# After（v2） %>
<%= t('.title') %>
```

**ただし 1 つだけ注意が必要なケースがあります。** `tt(...)` の戻り値を `truncate` / `length` / スライス（`[0..n]`）/ 正規表現マッチなどで**文字列加工している箇所**だけは、素朴に `t` へ変えると `tt` が潰していたバグ（開発環境でマーカートークンが混入する問題）が復活します。そこは middleware のラッパーを通らない **`I18n.t`（絶対キー）** へ移す必要があります。

```erb
<%# 文字列加工している箇所は I18n.t（絶対キー）へ %>
<%= truncate(I18n.t('views.foo.body')) %>
```

機械的に判定できないため、この種の箇所は 1 件ずつ確認します。**この仕分けと一括置換を支援する専用スキルが gem に同梱**されています（次項）。

#### 移行支援スキル `copy-tuner-to-t-migrate` の使い方

gem リポジトリの `skills/copy-tuner-to-t-migrate/` に、`tt` → `t` 移行を支援する Claude Code スキルが同梱されています。`app/` 配下の `.rb` / `.haml` / `.erb` を走査し、機械的に置換できる箇所を一括変換しつつ、文字列加工している箇所（`I18n.t`（絶対キー）へ要移行）を 1 件ずつ確認しながら進めます。

**1. スキルをアプリへ導入する**

移行対象アプリのルートで `gh skill` を使ってインストールします。

```bash
gh skill install SonicGarden/copy-tuner-ruby-client copy-tuner-to-t-migrate --agent claude-code
```

このスキルは破壊的な一括書き換えを含むため `disable-model-invocation: true` が付いており、**ユーザが明示的に呼んだときだけ**動きます。Claude Code で `/copy-tuner-to-t-migrate`（またはスキル名を指定）で起動してください。

**2. 定義側のシムに注意**

v2 を待つ間の後方互換として `ApplicationHelper` に `def tt(...) = t(...)` のような **`tt` の定義**を生やしているアプリがあります。これは「呼び出し」ではないので機械置換の対象外です（スキルも自動変換しません）。**呼び出しをすべて `t` / `I18n.t` へ移し終えてから**、この定義を手で削除してください（順序を逆にすると残った呼び出しが `NoMethodError` になります）。

どうしても `tt` という呼び名を残したいアプリは、`t` に委譲するだけの `tt` を自前で定義し続けても構いません（gem 撤去後は `t` と実質同義です）。

```ruby
# 自前で残す場合の例（任意）
module ApplicationHelper
  def tt(*args, **kwargs)
    t(*args, **kwargs)
  end
end
```

---

### 3. `config.html_escape` 設定を削除

**何が変わったか**

`config.html_escape` を削除しました。設定行が残っていると `NoMethodError` になります。

HTML の安全性判定は **i18n 標準**（`.html` / `_html` で終わるキーのみ `html_safe`）に統一されています。

**なぜ**

`html_escape` は v1 後期にはすでに参照されない no-op になっていました。安全性判定を i18n 標準へ一本化し、不要になった設定を撤去しました。

**移行手順**

initializer から該当行を削除します。

```ruby
# Before（v1）
config.html_escape = false # ← この行を削除

# After（v2）— 行ごと削除する
```

`html_escape = false`（全訳文を `html_safe` 扱いにする旧互換挙動）に依存していたアプリは、HTML を含む訳文のキーを **`.html` / `_html` で終わる命名へ移行**してください。移行漏れの検出には次の rake タスクが使えます。

```
bundle exec rake copy_tuner:detect_html_incompatible_keys
```

---

### 4. `config.exclude_key_regexp` を削除（→ `config.local_first_key_regexp`）

> このオプションを使っていないアプリ（大多数）は対応不要です。設定していた場合のみ読んでください。

`config.exclude_key_regexp` を削除しました。後継は `config.local_first_key_regexp` ですが、**対象キーの形式と挙動の両方が異なります**。

| | `exclude_key_regexp`（旧） | `local_first_key_regexp`（新） |
| --- | --- | --- |
| マッチ対象 | locale 付きキー（例 `ja.views.foo`） | **locale を除いた**キー（例 `views.foo`） |
| 挙動 | （除外） | lookup 時に CopyTuner キャッシュをスキップし、ローカル YAML を**完全優先**（完全分離） |

正規表現から **locale プレフィックスを外して** `local_first_key_regexp` へ移します。

```ruby
# Before（v1）
config.exclude_key_regexp = /\Aja\.views\./

# After（v2）— 先頭の locale（ja.）を外す
config.local_first_key_regexp = /\Aviews\./
```

マッチしたキーは CopyTuner キャッシュを一切参照せず、ローカル YAML のみを引きます（ローカルにも無ければ未訳）。詳細は README の「特定のキーをローカル YAML 優先にする（段階移行）」を参照してください。

---

## 挙動変更（対応は基本不要）

### Copyray オーバーレイのマーカー方式刷新

開発環境の Copyray オーバーレイ（翻訳を画面上で編集する仕組み）の内部マーカー方式を刷新しました。**アプリ側の対応は基本的に不要**です。

- 訳文への HTML コメント `<!--COPYRAY key-->` 注入をやめ、可視トークン `⟦CT:key⟧` を埋め込みます。`CopyrayMiddleware` がこれを `data-copyray-key` 属性へ変換し、トークンを HTML から完全に除去します。**最終配信 HTML にコメント・トークンは残りません**。
- 平文・`html_safe`（`.html` / `_html` キー）どちらの訳文もハイライト対象です。
- `<head>` 内（title / meta）はトークンを除去するのみでオーバーレイ非対象ですが、従来どおり CopyTuner バーのリスト導線から編集できます。

ただし、配信 HTML 中の `<!--COPYRAY ...-->` コメントを前提にしたカスタム処理（独自スクリプト等）がある場合は、コメントが出力されなくなるため見直しが必要です。

---

## アップグレード手順（チェックリスト）

1. **Ruby を 3.3 以上**にする。
2. Gemfile の `copy_tuner_client` を v2 系へ更新し、`bundle install`。
3. initializer に **`config.project_id`** を設定する（必須）。
4. ビュー内の **`tt` を `t`** へ置換する（移行支援スキル `copy-tuner-to-t-migrate` を利用）。文字列加工している箇所は `I18n.t`（絶対キー）へ。後方互換シム（`def tt`）があれば呼び出し移行後に削除する。
5. **`config.html_escape`** の行を削除する。`html_escape = false` に依存していた場合は、HTML 訳文のキーを `.html` / `_html` 命名へ移行（`rake copy_tuner:detect_html_incompatible_keys` で検出）。
6. （`config.exclude_key_regexp` を使っていた場合のみ）**`config.local_first_key_regexp`** へ移行する（locale プレフィックスを外す）。
7. 開発環境で起動し、`ArgumentError` / `NoMethodError` が出ないこと、翻訳表示と Copyray オーバーレイが正しく動くことを確認する。

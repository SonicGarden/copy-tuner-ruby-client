---
name: copy-tuner-to-t-migrate
description: >-
  copy_tuner_client v2.0.0 への移行で、削除された独自ヘルパー tt の呼び出しを Rails 標準の t（translate）へ
  置換するスキル。tt は PR #122 で存在理由を失い gem から削除されたため、残った tt(...) は NoMethodError に
  なる。大半は機械的に tt( → t( で済むが、訳文を文字列加工している箇所（→ I18n.t へ）と label 系ヘルパーの
  第一引数に渡している箇所（→ 引数構造を分離）だけは別扱いで、開発環境のマーカートークン残留バグを避けるため
  1 件ずつ確認する。対象は app 配下の .rb / .haml / .erb。
disable-model-invocation: true
license: MIT
---

# tt → t 移行スキル（copy_tuner_client v2.0.0）

copy_tuner_client がかつて `ActionView` にフックして生やしていた独自ヘルパー **`tt`**（シグネチャは
`tt(key, **options)`、引数は `t` と完全同一）を、Rails 標準の `t`（`translate`）へ置き換えるワークフロー。
gem を v2.0.0 に上げたアプリのビューに `tt(...)` が残っていると **`NoMethodError`（未定義ヘルパー）** になる。

このスキルは**破壊的な一括書き換え**を含むため、ユーザが明示的に呼んだときだけ動く（`disable-model-invocation`）。

## なぜ tt を t へ置換するのか

`tt` はもともと「**copyray マーカーを注入しない生の訳文を取る**」ためのヘルパーだった。旧方式では `t('key')` の
戻り値そのものにマーカーが埋め込まれ、`truncate` / `length` 等で**訳文を文字列加工する箇所**でマーカー長が
混入して壊れる問題があり、その対策が `tt` だった。

PR #122 のマーカー方式刷新で、マーカー注入は戻り値ではなく middleware（`CopyrayMiddleware` → `Rewriter`）で
行い HTML 配信前に完全除去するようになった。これにより通常の `t` がどこでも安全に使えるようになり、`tt` は
存在理由を失って削除された。背景の詳細は `skills/copy-tuner/SKILL.md` の「翻訳ヘルパー（`t`）」と
「落とし穴: 開発環境で訳文にマーカートークンが混入する」を参照。

**ただし罠が一つ残る。** マーカー除去は「最終的に HTML へ出力される訳文」に対してのみ効く。development で
`t('key')` の戻り値を**ビュー内で文字列加工する**コードは、除去前のマーカー込み文字列に作用してしまう（本番では
middleware 自体が無いので再現しない＝開発環境だけ壊れる）。

→ つまり **`tt` を素朴に `t` へ変えてよいのは「文字列加工していない箇所」だけ**。文字列加工している `tt` を
`t` にすると、`tt` がもともと潰していたバグをそのまま復活させてしまう。そこは middleware のラッパーを通らない
**`I18n.t`（絶対キー）** へ移すのが正解で、機械的には決められないため 1 件ずつ確認する。

## もう一つの罠: label の第一引数に渡す

文字列加工していなくても危険な経路がもう一つある。`t(...)` の戻り値を **`label` 系ヘルパーの第一引数**
（form builder の `f.label` / `label_tag` / 素の `label`）に渡しているケース:

```haml
= f.label t('activerecord.attributes.field.keywords'), class: 'form-label'
```

`f.label` の**第一引数は「ラベルテキスト」ではなく method 名**（`for` 属性・`id`・ラベル文字列の元）として
扱われる。そのため development では次の連鎖でマーカーが消せない位置に残る:

1. `t(...)` が `⟦CT:activerecord.attributes.field.keywords⟧分類` を返す。
2. `f.label` がこれを method 名と解釈し、**ラベルテキスト**と **`for` 属性**の 2 か所に展開する。
3. ラベルテキスト側は Rails の `humanize` で**小文字化**され `⟦ct:…⟧` になる。
4. Rewriter のマーカー検出プレフィックスは **大文字 `⟦CT:` 固定**（`lib/copy_tuner_client/copyray/marker.rb`
   の `PREFIX`）。小文字化された `⟦ct:` は一致せず、除去されないまま画面に残る。

これも v1.x では `tt`（マーカー無し版）だったため表面化せず、**`tt → t` 一括置換で初めて顕在化する回帰**。

**重要: このケースは `I18n.t` 化では直らない。** マーカーを消しても、`t`/`I18n.t` の戻り値（訳文文字列）を
`label` の第一引数に渡す構造自体が `humanize` / `for` 属性の挙動として不適切だからだ。正しい修正は
**method 名を第一引数・表示テキストを第二引数に分離**すること:

```haml
= f.label :keywords_cont, t('activerecord.attributes.field.keywords'), class: 'form-label'
```

`for` 属性が変わるので、ラベルクリックでフィールドにフォーカスが当たることを実機で確認する。
スクリプトはこのパターンを suspicious のサブ種別 `label_arg` として抽出する（`label:` オプションに渡す
simple_form の `f.input :x, label: tt('k')` も同様に拾う）。

## 変換の 3 分類

| 分類 | サブ種別 | 例 | 扱い |
|---|---|---|---|
| **safe** | — | `tt('views.foo')` / `= tt '.title'` / `tt(key, default: x)` / `f.label :method, tt('k')`（第二引数） | `tt(` → `t(` に決定論的一括変換 |
| **suspicious** | `string_manipulation` | `truncate(tt('k'))` / `tt('k').length` / `tt('k')[0..n]` / `tt('k') =~ /re/` / `tt('k').gsub(...)` 等 | `I18n.t('絶対キー')` へ。**1 件ずつ確認**。スクリプトは触らない |
| **suspicious** | `label_arg` | `= f.label tt('k')` / `label_tag tt('k')` / `f.input :x, label: tt('k')`（label 系の**第一引数 / label: オプション**） | **`f.label :method, t('k')` へ構造を直す**（method 名を第一引数・表示テキストを第二引数に）。**`I18n.t` 化では直らない**。1 件ずつ確認 |
| **other** | — | `def tt` / `alias tt`（定義側）/ app 外（`lib/` 等）/ `tt` を含む別識別子の誤検出 | 最後にまとめて提示。自動変換しない |

**重要（定義側の罠）:** アプリが v2.0.0 を待つ間の後方互換として `ApplicationHelper` に `def tt(key, **) = t(key, **)`
のような **`tt` の定義**を生やしていることがある。これは「呼び出し」ではないので `t(` へ機械置換すると Rails の `t`
を再定義して破滅する。スクリプトは `def tt` / `alias tt` を **other** に隔離して自動変換しない。**呼び出しを全て
`t` / `I18n.t` へ移し終えた後**に、この定義を手で削除する（順序を逆にすると呼び出しが `NoMethodError` になる）。

判定はヒューリスティック（完全な AST ではない）。**誤判定のコストが非対称**なので疑わしきは suspicious に倒す:
safe を取りこぼす（本当は怪しいのに safe）とマーカー混入バグが再発して重大、suspicious を過剰検出しても人間が
1 件確認するだけで軽微。

## ワークフロー

### 1. 利用箇所の洗い出しと 3 分類

同梱スクリプトで `app/` 配下の `.rb` / `.haml` / `.erb` を走査し、3 分類でレポートする（変更は加えない）。
Rails context は不要なので素の `ruby` で動く。

```bash
ruby skills/copy-tuner-to-t-migrate/scripts/migrate_tt.rb --report
```

safe / suspicious / other の件数と該当箇所（`ファイル:行: コード`）が出る。まず全体像をユーザと共有する。

### 2. safe な箇所を一括変換

safe 分類は引数がそのまま通る（`tt(key, **options)` → `t(key, **options)`）ので決定論的に置換できる。
**件数をユーザに伝え、承認を得てから**適用する（`--apply-safe` はファイルを直接書き換えるため）。

```bash
ruby skills/copy-tuner-to-t-migrate/scripts/migrate_tt.rb --apply-safe
```

suspicious / other の行は**一切触らない**（行番号で限定しているため）。適用後に `git diff` を見せて、safe 行
だけが `t(` になったことを確認してもらう。

### 3. suspicious な箇所を 1 件ずつ確認

ここが人間の判断が要る核心。手順 1 の suspicious 各件について、次を 1 件ずつ提示して確認を取る。
**suspicious はサブ種別（`[label_arg]` / `[string_manipulation]`）で修正方法が異なる**ので、種別で分岐する:

**`[string_manipulation]`（戻り値を文字列加工している）:**
- 該当コード（`ファイル:行`）と、なぜ怪しいか（戻り値を文字列加工している＝マーカー混入の危険）
- 提案する置換: `t(...)` ではなく **`I18n.t('絶対キー')`**（`I18n` モジュール直呼びはラッパーを通らずマーカーが付かない）

**`[label_arg]`（label 系の第一引数 / label: オプションに渡している）:**
- なぜ怪しいか（`humanize` で小文字化された `⟦ct:…⟧` が大文字 `⟦CT:` 固定の Rewriter をすり抜け残る。「もう一つの罠」参照）
- 提案する置換: **`I18n.t` 化ではなく引数構造を直す。** `= f.label t('views.foo.bar'), class: …` →
  `= f.label :method_name, t('views.foo.bar'), class: …`。第一引数の method 名（`for` 属性に使うシンボル）は
  ユーザに確認するか、対応する入力フィールド（`f.text_field :keywords_cont` 等）から推定する。
  `label:` オプション（`f.input :x, label: tt('k')`）の場合は引数構造はそのままで `t('k')` でよいことが多いが、
  そのフィールドのラベルが `humanize` を経るかは入力次第なので 1 件ずつ確認する。

注意点:
- **たとえユーザが「全部まとめて I18n.t にして」と言っても、suspicious は必ず 1 件ずつ提示する。** 相対キーを含む件は絶対キーをユーザと確認しないと置換できないためで、省略すると誤ったキーを書き込む危険がある。
- **相対キー（先頭ドット `tt('.foo')`）は `I18n.t` では解決できない。** 絶対キー（`I18n.t('views.foo.bar')`）へ
  書き換える必要があり、partial のパスからキーを補う判断が要る。スクリプトはこの相対キーの suspicious を
  `相対キー(.foo)は絶対キーへ書き換えが必要` と強調表示するので、特に丁寧に確認する。ヘルパーや
  コントローラ（`app/helpers/`, `app/controllers/`）に相対キーがある場合は、呼び出し元のビューのパスを
  調べて基点キーを特定するか、ユーザに直接絶対キーを確認する。絶対キーが不明なときは
  `grep -r "キー末尾部分" config/locales/` でロケールファイルを検索して候補を絞り込む。
- 本当に文字列加工していない（誤検出）なら、その場合は `t(...)` でよい。ユーザの判断に従う。
- **行をまたぐ変数経由（`txt = t('k')` → 別行で `f.label txt` や `truncate(txt)`）はスクリプトの行単位
  スキャンでは拾えない**（構造的限界）。最終防波堤は手順 5 の「実画面に小文字マーカー `⟦ct:…⟧` が出ないか目視」。

確認が取れた箇所だけ Edit で個別に置換する（スクリプトでは変換しない）。

### 4. その他ヒット（定義側・app 外・誤検出）を提示

手順 1 の other をまとめて提示する。

- **`def tt` / `alias tt`（定義側）**: 後方互換シムが残っていることが多い。**呼び出しを全て移し終えてから手で削除**する
  （3 分類表の「定義側の罠」参照）。早く消すと残った呼び出しが `NoMethodError` になる。
- **app 外（`lib/` のヘルパーやコントローラ等）**: ビューヘルパー `tt` がそのスコープから見えるかは別問題なので、
  自動変換せずユーザに判断を委ねる。

念のため、スクリプトの単語境界判定をすり抜けた可能性に備えて素朴な grep でも最終確認する:

```bash
git grep -nwI tt -- app   # -I でバイナリ（画像等）の誤マッチを除外
```

### 5. 検証

- `git grep -nwI tt -- app` の残りが「未対応の suspicious + まだ消していない定義側」だけであること
  （safe は 0 件、`I18n.t` 化した suspicious も `tt` としては消える）。
- 対象アプリで `bundle exec rspec`（または該当アプリのテスト）を回し、`NoMethodError` が出ないこと。
- development で実画面を開き、文字列加工していた箇所にマーカートークン（`⟦CT:...⟧`）が混入していないこと。
- **label を含む画面で、小文字マーカー `⟦ct:...⟧`（小文字 ct）が残っていないこと。** Rewriter は大文字
  `⟦CT:` しか除去しないため、`humanize` で小文字化された取りこぼしは**この目視が最終防波堤**になる
  （label 第一引数の罠・行をまたぐ変数経由はここで初めて顕在化することがある）。

## スクリプトの責務（決定論的な範囲のみ）

`scripts/migrate_tt.rb` は**機械的に確定できる部分だけ**を担う:

- `--report`（既定）: 3 分類を出力。`--json` で機械可読出力も可能。**ファイルは変更しない**。
- `--apply-safe`: safe 分類のみ `tt(` → `t(` を適用。suspicious / other は触らない。
- `--root DIR`: リポジトリルート指定（既定はカレント）。

suspicious の確定変換（`I18n.t` 化・相対→絶対キー）は機械的に決められないため**スクリプトは行わない**。
必ず手順 3 で人間が 1 件ずつ確認する。

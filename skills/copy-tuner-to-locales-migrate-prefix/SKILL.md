---
name: copy-tuner-to-locales-migrate-prefix
description: >-
  copy_tuner（CopyTuner / copy_tuner_client）で集中管理している i18n データを、prefix（正規表現）単位で
  Rails 標準の config/locales（YAML）管理へ段階移行するスキル。gem の local_first_key_regexp を使い、
  1 回につき 1 prefix をローカルへ寄せて regexp に積み上げる。全 prefix 完了後の gem 撤去は
  copy-tuner-to-locales-cleanup スキルで行う。
disable-model-invocation: true
---

# copy_tuner → config/locales 段階移行スキル（prefix 単位）

copy_tuner（`copy_tuner_client` gem）で集中管理している i18n データを、**prefix（正規表現）単位で**少しずつ
Rails 標準の `config/locales` 配下の YAML 管理へ移していくためのワークフロー。**1 回の実行で 1 prefix だけ**
移行し、これを繰り返す。全 prefix の移行が完了したら `copy-tuner-to-locales-cleanup` スキルで gem・CI・
deploy・docs・MCP をまとめて撤去する。

このスキルは**特定のリポジトリに依存しない**。project_id・ファイルパス・CI 構成はプロジェクトごとに異なるので、
固有値を覚えるのではなく**毎サイクル、自分が編集する箇所（initializer の regexp・config/locales）を探索して
見つけ直す**（手順 2）。種別ごとの典型例は `references/example-touchpoints.md` を参照。

## なぜ prefix 単位で段階移行するのか

一発で全 i18n をローカル化すると、移行漏れ（ローカル YAML に書き忘れたキー）が**一斉に未訳化**して事故になる。
prefix 単位なら、移した範囲だけが影響を受け、移行漏れはその範囲の未訳として小さく顕在化する。安全な prefix から
順に潰していける。

### 前提となる gem 機能（local_first_key_regexp）

[copy-tuner-ruby-client #110](https://github.com/SonicGarden/copy-tuner-ruby-client/pull/110) で追加された
`local_first_key_regexp` を使う。挙動の要点（`references/local-first-regexp.md` に詳細）:

- **locale を除いたキー**（`views.foo` 等）が regexp にマッチすると、`I18nBackend#lookup` は CopyTuner
  キャッシュもアップロードキューも**一切見ず**、Rails 標準バックエンド（`I18n::Backend::Simple`）に委譲して
  ローカル YAML だけを引く。これを**完全分離**と呼ぶ。
- 完全分離なので、**マッチキーがローカル YAML に無ければ即 `nil`（未訳）**。CopyTuner へフォールバックしない。
  これが「移行漏れを未訳として顕在化させる」仕組み。
- マッチしないキーは従来どおり CopyTuner キャッシュ優先 → 無ければローカル、という動作のまま。
- regexp は**単一**（配列非対応）。複数 prefix は `Regexp.union` で 1 本に積み上げる。

gem を残したまま regexp に prefix を足していくだけなので、移行途中でも CopyTuner と config/locales が安全に
共存する。

## ワークフロー（1 サイクル = 1 prefix）

### 1. gem 前提確認

`local_first_key_regexp` が使えるバージョンの `copy_tuner_client` が入っているか確認する。

```bash
bin/rails runner 'p CopyTunerClient.configuration.respond_to?(:local_first_key_regexp)'
```

`true` でなければこのスキルは使えない。gem を PR #110 が入ったバージョンへ上げてから（`Gemfile` 更新 →
`bundle update copy_tuner_client`）出直す。**バージョンアップはこのスキルの前提条件**であり、ここで止める。

### 2. 編集対象の場所を確認（毎サイクル）

このスキルが**実際に編集するのは次の箇所だけ**なので、毎サイクル開始時にこれらの場所を軽く確認する。
grep 結果はセッションをまたいで残らない（複数セッションに分割して進める前提）ため、「初回に把握したはず」に
頼らず毎回見つけ直す。`vendor/`・`tmp/`・`node_modules/`・`Gemfile.lock` は除外する。

```bash
# 毎サイクル触る: initializer の local_first_key_regexp と config/locales の採番慣習
git grep -nI 'local_first_key_regexp' -- ':!vendor' ':!tmp' ':!node_modules'
ls config/locales

# 初回だけ触る（手順 9・10 用）: CI の export ステップと i18n 方針ドキュメント
git grep -nI -e 'copy_tuner:export' -e 'CopyTuner' -- '.github/' 'doc/' 'CLAUDE.md'
```

- 手順 6・7 で毎回触る **initializer の `local_first_key_regexp`** の位置と、**`config/locales/`** の採番慣習
  （例: `00_`・`10_`）を確認する。
- 手順 9（CI の export ステップ削除）・手順 10（方針ドキュメントの中間状態更新）で**初回だけ**触る箇所も
  ここで場所だけ押さえる。

#### 2-1. （初回のみ）既存 locales を `0000_original_` プレフィックスへリネーム

このスキルの分割方針（手順 6）は、**既存 `config/locales` をロード最先頭に固定し、移行で足すファイルを後ろに
置いて Rails i18n の後勝ちで上書きする**ことを前提にする。そのため**初回サイクルの最初に一度だけ**、既存の
locales ファイルを `0000_original_` プレフィックスへリネームする。

```bash
# 例（既存ファイル名に合わせて読み替える）:
git mv config/locales/00_ja.yml         config/locales/0000_original_ja.yml
git mv config/locales/00_devise.ja.yml  config/locales/0000_original_devise.ja.yml
git mv config/locales/10_app.yml        config/locales/0000_original_app.yml
```

- **初回判定**: `ls config/locales` に `0000_original_` で始まるファイルが既にあれば、このリネームは済んでいる
  のでスキップする（2 サイクル目以降は常にスキップ）。
- `0000_` は数値プレフィックスで必ず最先頭ロードになる。以降 migrate で足すファイルは `0010_` 以降に置き
  （手順 6）、ロード順で後勝ち＝オリジナルを上書きする。`Regexp.union` の積み上げ（手順 7）と合わせ、
  「重複キーは export 側を正とする」を**手作業マージなしで構造的に保証**するのがこの固定の狙い。
- このリネームは**ファイルの中身を一切変えない**（純粋にロード順を確定するだけ）。リネーム後に rspec を流し、
  `translation missing` が**増えていない**ことだけ確認する。

gem・CI の deploy ワークフロー・deploy フック・MCP 設定の**撤去**は `copy-tuner-to-locales-cleanup` の仕事で、
cleanup は自前で touchpoint を grep し直す。**このスキルでそれらを棚卸し・編集する必要はない**。種別ごとの
典型的な在処は `references/example-touchpoints.md` を参照。

### 3. 残 prefix の把握

全件を export して俯瞰し、移行済み（現在の `local_first_key_regexp` がマッチする）prefix と未移行 prefix を
一覧化する。export は一時ファイルへ書く（`tmp/` 等の捨て場）。

```bash
bundle exec rake copy_tuner:export[tmp/copy_tuner_all.yml]
```

このタスクは内部で `CopyTunerClient.cache.sync` を呼び、サーバから最新を取得してから全 blurb を書き出す
（全件取得の唯一確実な手段。詳細は `references/export-and-split.md`）。出力 YAML のトップセクションを眺めて、
どの prefix が残っているかを確認する。

### 4. 対象 prefix の選定

残 prefix から **1 つ**選ぶ。影響が小さく構造が安定したものから始め、最後に大物（`views`）を回す:

1. **gem 由来（最安全・先行）**: `devise` / `good_job` / `ice_cube` / `restrict_dependent_destroy` 等。
   値が安定しアプリ実装に依存しにくい。
2. **Rails 標準フォーマット**: `date` / `time` / `datetime` / `number` / `helpers` / `text`。
   ただし**非表現値**（配列・シンボル・数値）の注意あり（手順 6）。
3. **バリデーションメッセージ**: `activerecord.errors` / `activemodel.errors`。テストで検知しやすい。
4. **モデル名・カラム名**: `activerecord.models` / `activerecord.attributes` / `activemodel.attributes` /
   `activerecord.enums`。プロジェクトの i18n 方針で「新規キー登録の例外」とされていることが多い
   （プロジェクトの i18n 方針ドキュメントでそう規定されていることが多い）。**全撤去がゴールなのでこの prefix も最終的に移行対象に含める**。
   例外規定の撤廃は cleanup で行う。
5. **画面テキスト（最大・最後）**: `views` / `text`。量が多く画面影響が大きいので最後に回し、画面確認の比重を
   上げる。1 回が大きすぎるなら `views.<controller>.` の 2 階層目で更に刻んでよい（regexp を `\Aviews\.users\.`
   のように書ける）。

### 5. 不正キーの事前チェック（関門）

export 済み YAML を config/locales に持ち込む前に、不正キーがないことを確認する。

```bash
bundle exec rake copy_tuner:detect_conflict_keys
bundle exec rake copy_tuner:detect_html_incompatible_keys
```

- `detect_conflict_keys` … キー衝突。`foo` という値キーと `foo.bar` というネストキーが同居すると YAML へ
  正しく展開できない。
- `detect_html_incompatible_keys` … `html_escape` 有効環境で `.html` 慣習と矛盾する値など。

これらのタスクは**全キー対象**で prefix 絞り込み引数は無い。**出力のうち今回の対象 prefix に該当する行だけ**を
関門にする（対象外 prefix の不正キーは、その prefix を移す回まで保留してよい）。該当があれば**そのまま
config/locales に持ち込むと壊れる**ので、一覧をユーザーに報告し、copy_tuner の管理画面側で修正してもらってから
進む。（タスクが見つからない場合は `bundle exec rake -T copy_tuner` で確認。）

### 6. 対象 prefix を config/locales へ配置（スクリプトで一気通貫）

配置・移行漏れ検証・オリジナルからの削除は決定論的なので、手作業でなく `scripts/migrate_prefix.rb` を
`bin/rails runner` で実行する。**1 本のスクリプトで配置 → 静的ガード → 移行漏れ検証 → オリジナル削除まで**
一気通貫で行い、漏れが 1 件でもあれば**オリジナルを一切変更せず中断**する。

```bash
bin/rails runner .claude/skills/copy-tuner-to-locales-migrate-prefix/scripts/migrate_prefix.rb \
  -- --prefix date --export tmp/copy_tuner_all.yml --out config/locales/0010_date.yml
```

- `--prefix` … 今回移行する prefix（ドット区切り。`date` / `activerecord.attributes` 等）。
- `--export` … 手順 3 で出した全件 export YAML。
- `--out` … 移行分の配置先。**オリジナル（`0000_original_*.yml`）より後にロードされる採番**（`0010_` 以降）。
  採番慣習は手順 2 で確認したものに合わせる。
- `--regexp` … 省略時は prefix から `/\A<prefix>\./` を自動生成（手順 7 の `local_first_key_regexp` と整合）。
  2 階層目で刻む（`views.users` 等）ときだけ明示する。
- `--locales` … 省略時は `I18n.available_locales`（`default_locale` を先頭）を対象 locale にする。`--locales ja,en`
  のように明示すると上書きできる（fixture を使った検証用）。スクリプトは対象 locale すべてを横断して配置・
  検証・削除する（単一ロケール運用でも、将来 locale を足しても自動追従する）。

スクリプトの動作（詳細・設計判断は `references/export-and-split.md`）:

配置・検証・削除は対象 locale（`--locales`／既定は `I18n.available_locales`）ごとに独立して行い、`--out` には
全 locale のサブツリー（`ja:` / `en:` …）を書き出す。あるロケールに当該 prefix のキーが無ければ warn して
そのロケールはスキップする。

1. **配置**: オリジナル全ファイルから対象 prefix サブツリーを抽出し（ファイル名昇順＝ロード順で deep merge）、
   export サブツリーを**その上に deep merge**（String blurb は export 勝ち）、最後に**オリジナル由来の非表現値
   （配列・シンボル・数値・真偽値）を再適用**して `--out` へ書き出す（`deep_merge(deep_merge(orig, exp), non_blurb)`）。
   「export を正とする」を満たしつつ、**非表現値は orig 値が必ず勝つ**（export 側に壊れた非表現値が出ても置換
   されない。後述）。
2. **静的ガード**: YAML ラウンドトリップ一致・`--out` が `config/locales` 配下の `.yml`（次回起動の i18n glob で
   ロードされる場所）・全 leaf キーが regexp にマッチ、を確認（採番ミス・regexp 不一致・YAML 崩れの早期検出）。
3. **移行漏れ検証**: オリジナル削除を**メモリ上でシミュレート**し、削除後ツリーを素の `I18n::Backend::Simple` に
   載せて対象 prefix の全キーを実 lookup。`translation missing` になるキーがあれば漏れ。
4. **ゲート**: 漏れゼロのときだけオリジナルから該当サブツリーを削除（空親も刈る）。漏れがあれば中断。

**非表現値が必ず orig 値で残る**: copy_tuner は flat な文字列 blurb しか持てないため、配列・シンボル・数値・
真偽値（`date.order` の `:year`、`date.*_names`、`number.*.precision`／`*.significant` 等）は export に出てこない
／壊れて（文字列化して）出てくる可能性がある。スクリプトは export を上書きした**後に**、オリジナル由来の
非表現値（非 String leaf）を再適用するので、**export 側に壊れた値が出ても orig の正値が置換勝ちする**。同じ
prefix 内で `date.formats`（文字列・export 勝ち）と `date.order`（シンボル配列・orig 勝ち）が住み分く。現スキルが
以前使っていた `0005_rails_non_blurb.yml` への別隔離は**不要**（このスクリプトに吸収済み）。

> NOTE: 削除は手順 8 ではなく**このスクリプト内で**完結する（移行漏れ検証を通った場合のみ）。オリジナルを
> 残したまま検証しても、オリジナルが漏れを埋めてしまい未訳検知が無意味になるため、検証と削除を同一スクリプトに
> 束ねている。スクリプトが中断した場合は `--out` のファイルだけが残る（オリジナルは無傷）ので、原因を直して
> 再実行するか `--out` を消してやり直す。

### 7. local_first_key_regexp に prefix を追加

initializer（`config/initializers/copy_tuner.rb` 等）の `CopyTunerClient.configure` ブロックで、
`local_first_key_regexp` を `Regexp.union` で組み直し、今回の prefix を 1 本足す。

```ruby
config.local_first_key_regexp = Regexp.union(
  /\Adevise\./,
  /\Aice_cube\./,
  /\Aviews\./,            # ← 今回追加した prefix
)
```

**必ず `\A` でアンカーする**（`views` が `reviews` に部分マッチする事故を防ぐ。キーは locale 除去後なので
`\A` 起点で良い）。詳細・なぜ単一 Regexp なのかは `references/local-first-regexp.md`。

### 8. 検証（任意・ユーザー判断）

手順 6 のスクリプトが**移行漏れ（削除後に未訳化するキー）がゼロであることを機械的に確認した上で削除**まで
済ませている（メモリ上で削除をシミュレートし、素の `I18n::Backend::Simple` で対象 prefix の全キーを実 lookup）。
そのためスキルとしての rspec/画面確認は**必須にしない**。すべて git 管理下なので、問題があれば戻せる。

ただしスクリプト内の検証は**静的キー集合とロード経路**までしか見ない。次の**実行時コンテキスト依存**の範囲は
カバーしないので、必要に応じてユーザー判断で確認する:

- lazy lookup `t('.key')` … 実際の controller/view コンテキストでフルキーが決まる。
- 動的キー `t("views.#{type}.title")` … 静的に列挙できないキー。
- `_html` の表示崩れ・補間 `%{...}` … lookup 成功と表示の正しさは別。

確認したい場合は rspec（`docker compose up -d db` → `bundle exec rspec`）や主要画面で `translation missing` が
出ないか見る。i18n 参照パターンの確認例は `references/verification-per-prefix.md`。

> NOTE: regexp 追加（手順 7）後にスクリプトの regexp 引数と `local_first_key_regexp` がずれていないか、
> `bin/rails runner 'p CopyTunerClient.configuration.local_first_key?("<prefix>.foo")'` が `true`、隣接キー
> （`reviews.*` 等）が `false` になることを確認しておくとよい。

### 9. （初回のみ）CI の Export ステップを削除

CI で copy_tuner を export しているステップ（テストワークフロー内で `bin/rake copy_tuner:export` を走らせる類）
は、**テスト起動前にローカルキャッシュを温める保険**にすぎない。
このステップを削除すると、test 環境は initializer 起動時の `cache.download`（CopyTuner サーバから都度取得）
だけになり、**本番と同じ挙動**になる。未移行 prefix も引き続きサーバから解決できるので、移行途中に消しても安全。

> WARNING: `config.disable_test_translation = true` は**入れない**こと。入れると test で CopyTuner DL が
> 止まり、未移行 prefix が一斉に未訳化する。Export ステップ（保険）だけを消すのが正しい。

### 10. ドキュメントの中間状態を更新

i18n 方針ドキュメント（`doc/` 等）が「copy_tuner で管理／config/locales は使わない」のまま残ると、移行途中で
他の作業者や AI が「新規キーを copy_tuner と locales のどちらに足すか」を誤判断する。**移行中であることと、
現在ローカル化済みの prefix を明記する**。中間状態テンプレ文は `references/example-touchpoints.md` にある。
prefix を増やすたびに、列挙も更新する。

### 11. 残 prefix を報告

移行済み prefix・残 prefix の一覧と、現在の `local_first_key_regexp` を報告して 1 サイクル終了。
残 prefix があれば次サイクルでこのスキルを再実行する。全 prefix が移行済みになったら
`copy-tuner-to-locales-cleanup` スキルへ進む。

## 1 サイクル完了の目安

- 手順 6 のスクリプトが**移行漏れゼロを確認して正常終了**し、`--out`（`0010_` 以降）に対象 prefix が配置され、
  `0000_original_*.yml` から該当サブツリーが削除されている（非表現値は `--out` 側に保持済み）。
- `local_first_key_regexp` に対象 prefix が `\A` アンカー付きで追加されている（手順 7）。
- 中間状態ドキュメントの「ローカル化済み prefix」が更新されている（手順 10）。
- （任意）rspec/画面で `translation missing` が出ないことをユーザー判断で確認（手順 8）。

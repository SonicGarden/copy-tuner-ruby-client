---
name: copy-tuner-to-locales-migrate-prefix
description: >-
  copy_tuner（CopyTuner / copy_tuner_client）で集中管理している i18n データを、prefix（正規表現）単位で
  Rails 標準の config/locales（YAML）管理へ移すスキル。gem の local_first_key_regexp を使うので、
  gem を残したまま特定 prefix だけをローカル管理にできる（部分ローカル化）。1 回の実行で 1 prefix。
  全 prefix を移して gem ごと撤去したい場合は繰り返し、完了後 copy-tuner-to-locales-cleanup スキルへ進む。
  対象 prefix はスキル引数で指定でき、未指定なら export を俯瞰して選定する。
disable-model-invocation: true
---

# copy_tuner → config/locales prefix 単位ローカル化スキル

copy_tuner（`copy_tuner_client` gem）で集中管理している i18n データを、**prefix（正規表現）単位で**
Rails 標準の `config/locales` 配下の YAML 管理へ移すためのワークフロー。**1 回の実行で 1 prefix だけ**扱う。

使い方は 2 つある:

- **部分ローカル化** — 特定 prefix だけを恒久的に `config/locales` 管理にする。**gem は残したまま**で、
  CopyTuner 管理と locales 管理の二層が**定常状態**になる。
- **全移行** — 上記を全 prefix ぶん繰り返す。全 prefix の移行が完了したら
  `copy-tuner-to-locales-cleanup` スキルで gem・CI・deploy・docs・MCP をまとめて撤去する。

**どちらの用途でもこのスキルがやること（手順 0〜10）は同一**で、差は「何回回すか」と「最後に cleanup へ
進むか」だけ。

このスキルは**特定のリポジトリに依存しない**。project_id・ファイルパス・CI 構成はプロジェクトごとに異なるので、
固有値を覚えるのではなく**毎サイクル、自分が編集する箇所（initializer の regexp・config/locales）を探索して
見つけ直す**（手順 2）。種別ごとの典型例は `references/example-touchpoints.md` を参照。

## なぜ prefix 単位で切るのか

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

gem を残したまま regexp に prefix を足していくだけなので、CopyTuner と config/locales は安全に共存する。
部分ローカル化ならこの共存が定常状態、全移行なら移行途中の状態としてそのまま成り立つ。

## ワークフロー（1 サイクル = 1 prefix）

### 0. 対象 prefix の受け取り（引数）

スキル引数で対象 prefix を渡せる（例: `devise` / `activerecord.attributes` / `views.users`）。

- **引数あり** … それを今回の対象とし、**手順 4 の選定はスキップ**する。ただし**手順 3 の全件 export は
  実行する**（手順 6 の `--export` 入力として必須なので省けない）。
- 引数の prefix が export に**存在しなければ**、その旨をユーザーに報告して中断する（手順 6 のスクリプトも
  同じ条件で異常終了するが、手順 3 の時点で気づけるほうが早い）。
- **引数なし** … 従来どおり手順 4 の基準で 1 つ選び、**選定結果をユーザーに提示してから**手順 5 へ進む。

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

# 手順 9 用: i18n 方針ドキュメント
git grep -nI 'CopyTuner' -- 'doc/' 'CLAUDE.md'
```

- 手順 6・7 で毎回触る **initializer の `local_first_key_regexp`** の位置と、**`config/locales/`** の採番慣習
  （例: `00_`・`10_`）を確認する。
- 手順 9（i18n 方針ドキュメントの更新）で触る箇所も、ここで場所だけ押さえる。

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

全件を export して俯瞰し、ローカル化済み（現在の `local_first_key_regexp` がマッチする）prefix と
copy_tuner 管理のまま残っている prefix を一覧化する。export は一時ファイルへ書く（`tmp/` 等の捨て場）。

対象 prefix が引数で指定されている場合、この一覧化は**対象 prefix が export に存在することの確認と規模把握**の
ためになる（選定は不要）。いずれの場合も `rake copy_tuner:export` の**実行自体は必須**で、出力は手順 6 の
`--export` 入力になる。

```bash
bundle exec rake copy_tuner:export[tmp/copy_tuner_all.yml]
```

このタスクは内部で `CopyTunerClient.cache.sync` を呼び、サーバから最新を取得してから全 blurb を書き出す
（全件取得の唯一確実な手段。詳細は `references/export-and-split.md`）。出力 YAML のトップセクションを眺めて、
どの prefix が残っているかを確認する。

### 4. 対象 prefix の選定

**引数で prefix が指定されている場合はこの手順をスキップ**し、手順 5 へ進む。

残 prefix から **1 つ**選ぶ。以下の順序は**安全度の目安**で、影響が小さく構造が安定したものから始め、最後に
大物（`views`）を回す:

1. **gem 由来（最安全・先行）**: `devise` / `good_job` / `ice_cube` / `restrict_dependent_destroy` 等。
   値が安定しアプリ実装に依存しにくい。
2. **Rails 標準フォーマット**: `date` / `time` / `datetime` / `number` / `helpers` / `text`。
   ただし**非表現値**（配列・シンボル・数値）の注意あり（手順 6）。
3. **バリデーションメッセージ**: `activerecord.errors` / `activemodel.errors`。テストで検知しやすい。
4. **モデル名・カラム名**: `activerecord.models` / `activerecord.attributes` / `activemodel.attributes` /
   `activerecord.enums`。プロジェクトの i18n 方針で「新規キー登録の例外」とされていることが多い
   （プロジェクトの i18n 方針ドキュメントでそう規定されていることが多い）。**全 prefix を移行する場合は
   この prefix も対象に含める**（例外規定の撤廃は cleanup で行う）。
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

> NOTE: スクリプトは「対象 prefix の削除で実際に内容が変わったファイルだけ」を書き戻す（変更が無ければ
> `File.write` をスキップする）。とはいえ `--originals-glob` の指定ミス等で意図しないファイルが対象に
> 入っていないとも限らないため、実行後は必ず `git diff --stat config/locales/` で「対象 prefix を含む
> はずのファイルだけに差分が出ているか」を確認する。対象 prefix と無関係なはずのファイルに差分が出て
> いたら `git checkout -- <file>` で復元し、原因（`--originals-glob` や `--prefix` の指定）を見直す。

> NOTE: 書き戻されたファイルでは**コメント・空行が失われる**（YAML 標準ライブラリはこれらを保持しない。
> 値・エイリアス参照は保たれる）。`git diff` を見て惜しいコメントがあれば手で戻すこと。

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

### 9. i18n 方針ドキュメントを更新

i18n 方針ドキュメント（`doc/` 等）が「copy_tuner で管理／config/locales は使わない」のまま残ると、
他の作業者や AI が「新規キーを copy_tuner と locales のどちらに足すか」を誤判断する。用途に応じて書き分ける
（テンプレ文は `references/example-touchpoints.md` にある）:

- **部分ローカル化** … 「移行中」ではなく**恒久的な二層管理**として書く。「以下の prefix は config/locales
  管理」「それ以外は copy_tuner 管理」「新規キーの追加先はどちら」の 3 点を明記する。
- **全移行** … 「copy_tuner から config/locales へ段階移行中」＋現在ローカル化済みの prefix を列挙する
  （最終形への書き換えは cleanup で行う）。

いずれも prefix を増やすたびに列挙を更新する。

### 10. 結果を報告

今回ローカル化した prefix と、現在の `local_first_key_regexp` を報告して 1 サイクル終了。加えて:

- **部分ローカル化** … これで完了。残りの prefix は copy_tuner 管理のままが定常状態なので、次サイクルは不要。
- **全移行** … copy_tuner 管理のまま残っている prefix の一覧も報告する。残りがあれば次サイクルでこのスキルを
  再実行する。全 prefix がローカル化済みになったら `copy-tuner-to-locales-cleanup` スキルへ進む。

## 1 サイクル完了の目安

- 手順 6 のスクリプトが**移行漏れゼロを確認して正常終了**し、`--out`（`0010_` 以降）に対象 prefix が配置され、
  `0000_original_*.yml` から該当サブツリーが削除されている（非表現値は `--out` 側に保持済み）。
- `local_first_key_regexp` に対象 prefix が `\A` アンカー付きで追加されている（手順 7）。
- i18n 方針ドキュメントの「config/locales 管理の prefix」が更新されている（手順 9）。
- （任意）rspec/画面で `translation missing` が出ないことをユーザー判断で確認（手順 8）。

# 典型的な touchpoint（種別ごと）

copy_tuner（`copy_tuner_client` gem）を使う Rails アプリで、移行・撤去のときに触ることになる touchpoint を
種別ごとに整理したもの。**探索クエリを投げるとこういう種類の結果が返る**というサンプルとして読む。値やパスは
プロジェクトごとに違うので、これを暗記せず、各スキルの探索手順を必ず自分で走らせて発見すること
（migrate は手順 2、cleanup は手順 1）。

各 touchpoint に、どちらのスキルで触るかの印を付けた:

- **[migrate]** = `copy-tuner-to-locales-migrate-prefix`（このスキル）で触る。prefix 移行のたびに編集。
  migrate の手順 2 で見つけ直すのはこの印の箇所だけ。
- **[cleanup]** = `copy-tuner-to-locales-cleanup`（全 prefix 完了後）で触る。gem・CI・deploy・docs・MCP 撤去。
  撤去対象は cleanup の手順 1 で自前に grep し直す（migrate では棚卸ししない）。

## copy_tuner の典型的な touchpoint（種別ごと）

### gem 依存 — [cleanup]

```ruby
# Gemfile
gem 'copy_tuner_client'                                              # 全環境
gem 'copy_tuner_client-mcp', github: '<org>/copy_tuner_client-mcp',
    require: false                                                    # development, test
```

> 段階移行の前提として、`copy_tuner_client` は **PR #110（local_first_key_regexp）入りバージョン**へ
> 上げておく必要がある（migrate スキル手順 1 で確認）。

### 初期化子 — [migrate]（local_first_key_regexp を積み上げる中心）

`config/initializers/copy_tuner.rb`（パスはプロジェクトにより異なる）:

```ruby
CopyTunerClient.configure do |config|
  config.api_key = Rails.application.credentials.fetch(:copytuner_api_key) { ENV.fetch('COPYTUNER_API_KEY', 'dummy') }
  config.project_id = <プロジェクトの project_id>
  config.host = '<copy_tuner サーバの host>'
  config.html_escape = true
  config.locales = [:ja]
  config.ignored_keys = %w[]
  # 移行のたびにここへ prefix を足していく:
  # config.local_first_key_regexp = Regexp.union(/\Adevise\./, /\Aviews\./, ...)
end
```

→ `html_escape`（true 運用か）・運用ロケール（単一か複数か）という前提が分割・非表現値の判断に効くので、
実プロジェクトの initializer で確認する。initializer 全体の削除は [cleanup]。

> NOTE: `migrate_prefix.rb` は対象 locale を `I18n.available_locales`（既定。`--locales` で上書き可）から
> 取るので、運用ロケールが将来 `[:ja, :en]` 等に増えても引数なしで全ロケールを自動処理する（特定ロケール
> 決め打ちではない）。

### 既存 locales — [migrate]（先頭固定リネーム → prefix サブツリーを後ろへ配置 → オリジナルから削除）

移行前の既存ファイル（初回サイクルの手順 2-1 で `0000_original_` へリネームする）。実ファイル名はプロジェクト
ごとに異なるので `ls config/locales` で確認して読み替える。典型的には次のような種類が並ぶ:

- Rails 標準（date/time/number/errors/helpers）の YAML
- devise 等の gem 由来 YAML
- アプリ固有の `activerecord.enums` / `activerecord.attributes` 等を持つ YAML

→ オリジナルを `0000_original_` で先頭固定し、移行分は `0010_` 以降に置く。重複キーはロード順の**後勝ちで
export 側が勝つ**（手作業マージ不要）。prefix を移行するたびにオリジナルから該当サブツリーを削除し、残存＝
未移行 prefix の進捗マーカーにする（**全 prefix を移行する場合は最終的にオリジナルが空になる**）。
部分ローカル化では、対象外 prefix がオリジナルに残り続けるのが**定常状態**であり、空にならなくてよい。

→ Rails 標準フォーマットの **配列**（`date.abbr_day_names` 等）・`date.order` の `:year` 等の**シンボル配列**・
`number.*.precision` 等の**非表現値**は copy_tuner で表現できず export に出てこないため、`date`/`number` を移行
する回では手順 6 のスクリプトがオリジナル抽出分をベースに export を上書き（`orig_sub.deep_merge(exp_sub)`）して
移行分（`0010_` 以降）の中へ**非表現値ごと取り込む**。別ファイルへの隔離は不要（詳細は
`references/export-and-split.md`）。

### CI — [cleanup]

- **CI の翻訳 export ステップ**（テストワークフロー内で `bin/rake copy_tuner:export` を走らせる類）…
  「翻訳 DL 失敗でテストがコケないように」の保険。**[cleanup] で削除**（test が本番同等の
  `cache.download` 挙動になる）。`disable_test_translation` は入れない。
- **copy_tuner 専用の deploy ワークフロー**（main push で翻訳をデプロイする専用ファイル）…
  **[cleanup] で丸ごと削除**。
- **AI エージェント用ワークフローの `mcp__copy-tuner__*` allowedTools 許可** … **[cleanup] で削除**。

### deploy / 起動スクリプト — [cleanup]

- **deploy フック** … production 起動時に `bundle exec rake copy_tuner:deploy` を実行するブロック。削除。
- **コンテナ起動スクリプト** … 起動時に `rake copy_tuner:export` を走らせるフォールバック。**gem 撤去後は
  このタスク自体が消えて起動が `Don't know how to build task` で落ちる**ため、必ず削除する。取りこぼし注意。

### 環境設定 — [cleanup] で確認

`config/environments/production.rb` の `config.i18n.fallbacks = true` 等。標準バックエンドでも有効なので確認のみ。

### ドキュメント / スキル / MCP — [migrate]（用途別に更新） / [cleanup]（最終化・撤去）

- **i18n 方針ドキュメント**（`CLAUDE.md`・`doc/` 配下等）… 「copy_tuner サーバで i18n データを管理 /
  config/locales 配下は利用しない / 新規キー登録は基本禁止」等の記述。**[migrate] で更新**（部分ローカル化なら
  恒久的な二層管理として、全移行なら段階移行中の中間状態として。テンプレは後掲）。全移行の場合のみ
  **[cleanup] で最終化**。上記を参照している他のドキュメント（`CLAUDE.md` 等）も連動。
- **copy_tuner MCP 操作スキル**（`.claude/skills/` 配下）… **[cleanup] で無効化/削除**。
- **補助ドキュメント** … 「多言語対応: copy_tuner サーバで i18n データを管理」のような記述を持つコマンド定義等。
  **[cleanup] で修正**。
- **`README.md`** … CopyTuner プロジェクトへのリンク。**[cleanup] で削除/修正**。
- **`.mcp.json`** … copy-tuner MCP server 接続設定。**[cleanup] で削除**。

## 規模感

copy_tuner 側のキー数・export YAML の行数はプロジェクト次第だが、export YAML のトップには Rails i18n 慣習どおりの
セクションが並ぶ: `activemodel.attributes` / `activerecord.{attributes,enums,models,errors}` / `views` / `text` /
`helpers` / `date`/`time`/`datetime`/`number` / `devise` / `good_job` / `ice_cube` /
`restrict_dependent_destroy` 等。これらのトップセクションが prefix 移行の基本粒度。`views` が最大になりやすいので
最後に回す。

## i18n 方針ドキュメントテンプレ（[migrate] 手順 9 で使う）

用途に応じて 2 版ある。`<列挙>` は現在 `local_first_key_regexp` にマッチしている prefix に更新する
（prefix を増やすたびに更新）。

### 部分ローカル化版

「移行中」ではなく、この状態が**恒久的に続く二層管理**であることを明記する。

```markdown
### 国際化（i18n）

- **一部の prefix は config/locales（YAML）管理、それ以外は copy_tuner サーバ管理**
- config/locales 管理の prefix（`local_first_key_regexp` にマッチ）: `<列挙>`
- 上記以外の prefix は copy_tuner サーバで管理
- **新規キーの追加先**: 上記 prefix のキーは config/locales へ。それ以外は copy_tuner へ
- 複数形化対応は不要（日本語環境）
```

### 全移行版

「段階移行中」であることと、いずれ cleanup で最終化される中間状態であることを明記する。

```markdown
### 国際化（i18n）

- **copy_tuner から config/locales へ段階移行中**
- 以下の prefix は config/locales 管理へ移行済み（`local_first_key_regexp` にマッチ）: `<列挙: devise, ice_cube, views, ...>`
- 上記以外の prefix はまだ copy_tuner サーバで管理
- **新規キーの追加先**: 移行済み prefix のキーは config/locales へ。未移行 prefix のキーは従来どおり copy_tuner へ
- 複数形化対応は不要（日本語環境）
```

> 上記**全移行版にのみ係る注記**: [cleanup] で全 prefix 完了後、この中間記述は「config/locales 管理。
> copy_tuner 廃止。新規キーは config/locales へ。複数形化不要」に最終化する（モデル名・カラム名の例外規定も
> 撤廃）。部分ローカル化版は cleanup を経由しないため、この最終化は適用されない。

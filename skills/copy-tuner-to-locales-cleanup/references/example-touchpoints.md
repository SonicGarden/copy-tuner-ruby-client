# 典型的な touchpoint（種別ごと）

copy_tuner（`copy_tuner_client` gem）を使う Rails アプリで、移行・撤去のときに触ることになる touchpoint を
種別ごとに整理したもの。**探索クエリを投げるとこういう種類の結果が返る**というサンプルとして読む。値やパスは
プロジェクトごとに違うので、これを暗記せず、SKILL.md 手順 1 の grep を必ず自分で走らせて発見すること。

各 touchpoint に、どちらのスキルで触るかの印を付けた:

- **[migrate]** = `copy-tuner-to-locales-migrate-prefix`（このスキル）で触る。prefix 移行のたびに編集。
- **[cleanup]** = `copy-tuner-to-locales-cleanup`（全 prefix 完了後）で触る。gem・CI・deploy・docs・MCP 撤去。

## 手順1の grep が見つける touchpoint（種別ごと）

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
  # config.local_first_key_regexp = Regexp.union(/\Adevise\./, /\Aviews\./, ...)
end
```

→ `html_escape` 運用・運用ロケールという前提が分割・非表現値の判断に効く。initializer 全体の削除は [cleanup]。

### 既存 locales — [migrate]（先頭固定リネーム → 後ろへ配置 → オリジナルから削除）

migrate スキルで既存 locales を `0000_original_` へ先頭固定リネームし、移行分を `0010_` 以降に置く
（ロード順の後勝ちで export 側を正とする）。prefix を移行するたびにオリジナルから該当サブツリーを削除するため、
全 prefix 完了後の cleanup 時点では **`0000_original_*.yml` はほぼ空**になっている。

- `0000_original_*.yml`（既存・先頭固定） … 未移行 prefix の残り。全移行完了時点ではほぼ空。
- `0010_` 以降の移行分 … prefix 単位で配置した YAML。Rails 標準フォーマットの非表現値（`date.abbr_day_names`
  の配列・`date.order` のシンボル・`number.*.precision` の数値等）も migrate のスクリプトがこの中へ取り込んでいる。

→ cleanup では空になったオリジナルの扱い（削除するか空のまま残すか）は任意。非表現値は移行分（`0010_` 以降）に
取り込み済みで、gem 撤去後も Rails 標準フォーマットとして必要なので**消さない**。

### CI — [migrate]（Export ステップのみ初回で削除） / [cleanup]（残り）

- **CI の翻訳 export ステップ**（テストワークフロー内で `bin/rake copy_tuner:export` を走らせる類）…
  「翻訳 DL 失敗でテストがコケないように」の保険。**[migrate] の初回で削除**（test が本番同等の
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

### ドキュメント / スキル / MCP — [migrate]（中間状態更新） / [cleanup]（最終化・撤去）

- **i18n 方針ドキュメント**（`CLAUDE.md`・`doc/` 配下等）… 「copy_tuner サーバで i18n データを管理 /
  config/locales 配下は利用しない / 新規キー登録は基本禁止」等の記述。**[migrate] で中間状態に更新**、
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

## i18n 方針ドキュメント中間状態テンプレ（[migrate] 手順 10 で使う）

移行中はこのような記述に置き換える。`<列挙>` は現在 `local_first_key_regexp` にマッチしている prefix に
更新する（prefix を増やすたびに更新）。

```markdown
### 国際化（i18n）

- **copy_tuner から config/locales へ段階移行中**
- 以下の prefix は config/locales 管理へ移行済み（`local_first_key_regexp` にマッチ）: `<列挙: devise, ice_cube, views, ...>`
- 上記以外の prefix はまだ copy_tuner サーバで管理
- **新規キーの追加先**: 移行済み prefix のキーは config/locales へ。未移行 prefix のキーは従来どおり copy_tuner へ
- 複数形化対応は不要（日本語環境）
```

> [cleanup] で全 prefix 完了後、この中間記述は「config/locales 管理。copy_tuner 廃止。新規キーは
> config/locales へ。複数形化不要」に最終化する（モデル名・カラム名の例外規定も撤廃）。

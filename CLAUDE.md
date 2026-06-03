# CLAUDE.md

CopyTuner の Ruby クライアント gem。Rails アプリの I18n を CopyTuner サーバと同期する。

## コマンド
- テスト: `bundle exec rspec`（単一ファイル: `bundle exec rspec spec/copy_tuner_client/cache_spec.rb`）
- 特定の Rails バージョンでテスト: `BUNDLE_GEMFILE=gemfiles/8.0.gemfile bundle exec rspec`
- Lint: `bundle exec rubocop`（`sgcop` を継承）
- フロントエンドビルド: `yarn build`（開発: `yarn dev`）
- gem リリース: `bundle exec rake build|install|release`

## アーキテクチャ
`Configuration#apply`（lib/copy_tuner_client/configuration.rb）が全コンポーネントを組み立てる起点:
- `Client` — CopyTuner サーバ / S3 との HTTP 通信
- `Cache` — Mutex で保護された blurb ストア。Hash のように振る舞う。アップロードキューを管理
- `I18nBackend` — デフォルトの I18n backend を置き換える（`I18n.backend = ...`）。lookup で Cache を参照
- `Poller` / `ProcessGuard` — バックグラウンド同期スレッド
- Rack middleware `RequestSync` / `CopyrayMiddleware` — 開発環境でのリクエスト毎同期とオーバーレイ
Rails 統合は engine.rb のイニシャライザ経由（ヘルパー/SimpleForm フック、アセット precompile）。

## Gotchas
- **フロントエンドは `src/*.ts` を編集する。`app/assets/*` は Vite のビルド成果物なので直接編集しない**
  （vite.config.ts が `src/main.ts` → `app/assets/javascripts/copytuner.js` を出力）。
- キー除外の 2 オプションは混同しやすい:
  - `exclude_key_regexp` — locale 付きキー対象・アップロード時に作用
  - `local_first_key_regexp` — locale を除いたキー対象・lookup 時に作用（ローカル YAML 優先）
  local_first キーのアップロード抑止は `Cache#[]=` に集約されている。

## Claude Code スキル
`skills/copy-tuner/` に i18n キー操作支援スキルがある（SKILL.md 参照）。

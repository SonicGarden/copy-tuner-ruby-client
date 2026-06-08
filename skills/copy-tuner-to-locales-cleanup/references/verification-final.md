# 撤去後の最終検証

SKILL.md 手順 7 の詳細。copy_tuner 撤去後、翻訳が `config/locales` だけで完結することを確かめる。

## 1. 痕跡が残っていないか

```bash
git grep -niI -e 'copy.tuner' -e 'copytuner' -e 'CopyTunerClient' \
  -- ':!vendor' ':!tmp' ':!node_modules' ':!Gemfile.lock'
```

アプリ側のヒットがゼロになっていること（残っていれば手順 3〜6 の取りこぼし）。

## 2. gem が外れているか

```bash
grep -i copy_tuner Gemfile Gemfile.lock || echo 'removed'
bundle check
```

`Gemfile` / `Gemfile.lock` の双方から消えていること。`bundle install` 後に `bundle check` が通ること。

## 3. テスト

プロジェクトの品質コマンドに従う。多くの Rails プロジェクトでは:

```bash
docker compose up -d db   # 未起動なら
bundle exec rspec
```

migrate-prefix の初回で CI から copy_tuner export ステップを消し、ここで gem も外したので、テストが
**外部 API 接続なしで通る**ことが重要。落ちる場合は、テスト環境で参照しているキーが config/locales に
移っていない可能性が高い（完了判定の関門をすり抜けた漏れ）。

## 4. 未翻訳キーの検出

主要画面・主要フローを動かし、`translation missing` が出ないか確認する。ログから機械的に拾うなら:

```bash
grep -rni 'translation missing' log/ tmp/ 2>/dev/null || echo 'none'
```

より厳密にやるなら、開発・テスト環境で `config.i18n.raise_on_missing_translations = true` を一時的に
有効化してテストを流し、未定義キーで例外が出るかを確認する手もある（恒久設定にするかはプロジェクト判断）。

## 5. i18n の主要参照が解決するか

copy_tuner 撤去で影響しやすい参照パターンを、主要画面または rails runner で確認する:

- ビューの `t('...')` / `t('.lazy_key')`
- `Model.human_attribute_name(:attr)`（CSV ヘッダ・フォームラベル）
- `Model.model_name.human`
- enum の表示名（`human_enum_name` 等のヘルパ経由）

例:

```bash
bin/rails runner 'puts [User.model_name.human, User.human_attribute_name(:name)].inspect'
```

`translation missing` を含まず、期待する日本語が返ること。

## 6. Linter / セキュリティスキャン

プロジェクトで使われているものを流す。Rails プロジェクトの例:

```bash
bundle exec rubocop
bundle exec brakeman
# フロントエンドがあれば
pnpm biome check
```

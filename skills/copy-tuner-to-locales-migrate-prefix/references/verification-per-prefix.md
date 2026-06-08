# prefix 移行後の検証

SKILL.md 手順 8 の詳細。対象 prefix を `local_first_key_regexp` に足した後、その範囲がローカルだけで解決する
ことを確かめる。完全分離（マッチキーは CopyTuner を見ない）なので、ローカルへの書き忘れは未訳として現れる。

## 1. regexp が意図どおりマッチするか

gem の判定そのものを使って、今回の prefix のキーがマッチし、隣接キーが誤マッチしないことを確認する。

```bash
bin/rails runner 'p [
  CopyTunerClient.configuration.local_first_key?("views.foo.bar"),   # => true を期待
  CopyTunerClient.configuration.local_first_key?("reviews.foo")      # => false を期待（部分マッチ事故の確認）
]'
```

## 2. テスト

プロジェクトの品質コマンドに従う。多くの Rails プロジェクトでは:

```bash
docker compose up -d db   # 未起動なら
bundle exec rspec
```

`translation missing` が出ないこと。完全分離した prefix のキーがローカル YAML に揃っていないと、ここで
未訳が顕在化する（それが狙い）。落ちたら、抜き出したサブツリーに漏れがないか・配置ファイルがロードされて
いるかを確認する。

## 3. 未翻訳キーの検出

対象 prefix が関わる主要画面・フローを動かし、`translation missing` が出ないか確認する。
ログから機械的に拾うなら:

```bash
grep -rni 'translation missing' log/ tmp/ 2>/dev/null || echo 'none'
```

より厳密にやるなら、開発・テスト環境で `config.i18n.raise_on_missing_translations = true` を一時的に
有効化してテストを流し、未定義キーで例外が出るかを確認する手もある（任意・恒久設定にするかはプロジェクト判断）。

## 4. i18n の主要参照が解決するか

移行した prefix に応じて、影響しやすい参照パターンを主要画面または rails runner で確認する:

- `views.*` を移したら … ビューの `t('...')` / `t('.lazy_key')`
- `activerecord.attributes` を移したら … `Model.human_attribute_name(:attr)`（CSV ヘッダ・フォームラベル）
- `activerecord.models` を移したら … `Model.model_name.human`
- `activerecord.enums` を移したら … enum の表示名（`human_enum_name` 等のヘルパ経由）

例:

```bash
bin/rails runner 'puts [User.model_name.human, User.human_attribute_name(:name)].inspect'
```

`translation missing` を含まず、期待する日本語が返ること。

## 5. 移行していない prefix が壊れていないこと

未移行 prefix は `local_first_key_regexp` にマッチしないので、引き続き CopyTuner から引かれる。今回の移行で
未移行 prefix の表示が変わっていないことも、主要画面で軽く確認しておく（regexp のアンカー漏れで意図せず
広くマッチしていないかの確認も兼ねる）。

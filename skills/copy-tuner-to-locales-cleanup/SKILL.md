---
name: copy-tuner-to-locales-cleanup
description: >-
  copy_tuner（CopyTuner / copy_tuner_client）の全 i18n キーを config/locales へ prefix 単位で移行し終えた後、
  gem・初期化子・CI・deploy・ドキュメント・MCP 設定を一括撤去して copy_tuner 依存を完全に取り除くスキル。
  prefix 単位の移行は copy-tuner-to-locales-migrate-prefix スキルで先に完了させておくこと。
disable-model-invocation: true
---

# copy_tuner 撤去スキル（クリーンアップ）

`copy-tuner-to-locales-migrate-prefix` スキルで**全 prefix を config/locales へ移行し終えた後**に、
1 回だけ実行する。`local_first_key_regexp` が全キーを覆っている（= もう CopyTuner から引かれるキーが無い）
ことを確認してから、gem・初期化子・CI・deploy・ドキュメント・MCP 設定をまとめて撤去する。

このスキルは**特定のリポジトリに依存しない**。固有値を覚えず、毎回リポジトリを探索して touchpoint を発見する。
種別ごとの典型的な在処は `references/example-touchpoints.md` を参照。

## なぜ完了判定を関門にするのか

`local_first_key_regexp` でカバーできていない prefix が 1 つでも残ったまま gem を抜くと、その prefix のキーが
config/locales に無く、**一斉に未訳化**する。だから「全キーが regexp にマッチしている」ことを gem 撤去前の
**関門**にする。判定には gem 自身の `local_first_key?` を使い、export した全キーを 1 件ずつ通す。

## ワークフロー

### 1. 完了判定（関門）

CopyTuner の全キーが `local_first_key_regexp` にマッチする（= 全 prefix 移行済み）ことを確認する。

```bash
# 全件 export（一時ファイルへ。読み取り専用検証だが export は書き込むので捨て場へ）
bundle exec rake copy_tuner:export[tmp/copy_tuner_check.yml]
```

export YAML から locale を除いた全キーを取り出し、**gem の判定そのもの**で 100% マッチを確認する:

```bash
bin/rails runner '
  require "yaml"
  data = YAML.load_file("tmp/copy_tuner_check.yml")
  locale = data.keys.first                      # 例: "ja"
  keys = []
  walk = ->(h, prefix) do
    h.each do |k, v|
      key = prefix.empty? ? k.to_s : "#{prefix}.#{k}"
      v.is_a?(Hash) ? walk.call(v, key) : keys << key
    end
  end
  walk.call(data[locale], "")
  unmatched = keys.reject { |k| CopyTunerClient.configuration.local_first_key?(k) }
  if unmatched.empty?
    puts "OK: 全 #{keys.size} キーが local_first_key_regexp にマッチ。cleanup へ進める。"
  else
    puts "STOP: 未マッチ #{unmatched.size} 件（未移行 prefix が残存）。migrate-prefix へ戻る。"
    puts unmatched.first(30)
  end
'
```

`STOP` が出たら **cleanup を中止し、`copy-tuner-to-locales-migrate-prefix` で残 prefix を移行してから出直す**。
`OK` のときだけ次へ進む。

> NOTE: ここで `export` を実行できるのは gem がまだ入っているから。完了判定は gem 撤去より**前**に行う。

> 補助目印: migrate は prefix を移すたびにオリジナル（`0000_original_*.yml`）から該当サブツリーを削除するので、
> 全移行完了時点で `0000_original_*.yml` はほぼ空（残るのは非表現値の隔離 `0005_rails_non_blurb.yml` 等のみ）に
> なっているはず。`local_first_key?` のマッチ判定が主の関門で、ファイルが空かどうかは副次的な目視確認。
> 食い違うとき（regexp は全マッチなのにオリジナルに blurb 化できるキーが残っている等）は削除漏れを疑う。

### 2. 最終不正キーチェック

gem を抜く前の最終ゲートとして、全キーに不正がないことを確認する。

```bash
bundle exec rake copy_tuner:detect_conflict_keys
bundle exec rake copy_tuner:detect_html_incompatible_keys
```

両方が `All success` を出すこと。列挙された場合はそのキーが config/locales で壊れている可能性があるので、
migrate-prefix 側で配置を直してから戻る。

### 3. `tt` ヘルパーをアプリ側へ退避

copy_tuner_client は `ActionView` の `translate` をフックする際に **`tt` という独自エイリアス**を生やす
（copyray コメント注入なしの純粋な翻訳。シグネチャは `tt(key, **options)`）。アプリのビューが `tt(...)` を
使っていると、gem 撤去で `tt` が消えて `NoMethodError`（テンプレートで未定義ヘルパー）になる。**gem を抜く前に**
アプリ側へ移しておく。

1. 利用箇所を洗い出す（残っていれば移行対象）:

   ```bash
   git grep -nw tt -- app lib | grep -v 'attr\|http\|setting'   # 単語境界で tt のみ。誤検出は目視で除外
   ```

2. アプリのヘルパー（`app/helpers/application_helper.rb` 等。全ビューから見える場所）に、**非推奨警告付きで
   `t` に委譲するだけ**の `tt` を定義する。中身は `t` を呼ぶだけでよい（gem 撤去後は `translate` に copyray
   コメントが付かないので、`tt` と `t` は実質同義になる）:

   ```ruby
   # NOTE: copy_tuner_client が生やしていた tt ヘルパーの後方互換。gem 撤去で未定義になるため退避した。
   #       copyray コメント注入は廃止済みなので t と同義。新規コードでは t を使い、既存呼び出しは順次 t へ置換する。
   def tt(key, **options)
     ActiveSupport::Deprecation.new.warn('tt は非推奨です。t を使ってください。')
     t(key, **options)
   end
   ```

   > NOTE: `tt` はビューヘルパーなので、コントローラ等から呼んでいないか手順 1 で必ず確認する。ビュー専用なら
   > `ApplicationHelper` でよいが、別 namespace のヘルパーでしか使われていない場合はそのスコープに合わせる。

3. （任意・推奨）`tt(` を `t(` へ機械置換して呼び出し自体を消すと、非推奨ヘルパーを残さずに済む。置換する場合は
   引数がそのまま通る（`tt(key, **options)` → `t(key, **options)`）。置換後は手順 1 の grep が 0 件になること。
   置換しない場合は手順 2 のヘルパーを残し、警告ログで段階的に潰す。

### 4. 初期化子と gem を撤去

1. 初期化子（`config/initializers/copy_tuner.rb` 等）を削除（`local_first_key_regexp` ごと消える）。
2. `Gemfile` から copy_tuner 系 gem（`copy_tuner_client`, `copy_tuner_client-mcp` 等）を削除。
3. `bundle install` で `Gemfile.lock` を再生成。

これで I18n バックエンドが gem 製（`CopyTunerClient::I18nBackend`）から Rails 標準に戻り、`t()` への
copyray コメント注入も消える。あわせて `config/environments/*.rb` の `i18n.fallbacks` 等が gem に依存して
いないか確認する（標準バックエンドでも挙動が変わらないこと）。

### 5. CI を撤去

リポジトリ探索で見つけた CI の copy_tuner 痕跡を削除する。典型的には:

- copy_tuner 専用の deploy ワークフローファイル（main push で翻訳をデプロイする専用ファイル）… 丸ごと削除。
- AI エージェント用ワークフローの `mcp__copy-tuner__*` allowedTools 許可 … 削除。
- CI の「翻訳を export するステップ」… migrate-prefix の初回で削除済みのはず。**まだ残っていれば**ここで削除する
  （`git grep copy_tuner .github/` で確認）。

### 6. deploy / 起動スクリプトを撤去

- deploy フックの `rake copy_tuner:deploy`（production 起動時に実行されるブロック）… 削除。
- コンテナ起動スクリプトの `rake copy_tuner:export` フォールバック … **必ず削除**。
  gem 撤去後はこのタスク自体が消えており、残すとコンテナ起動が `Don't know how to build task` で落ちる。取りこぼし注意。

### 7. ドキュメント / スキル / MCP を撤去・方針最終化

方針ドキュメントが「copy_tuner で管理」や「移行中」のまま残ると、将来の作業者や AI が矛盾した行動を取る。
コードと方針を必ず揃える。

- i18n 方針ドキュメント（`CLAUDE.md`・`doc/` 配下等）を **config/locales 管理に
  最終化**する。migrate-prefix が残した「移行中」の中間記述を、「config/locales で管理。copy_tuner は廃止。
  新規キーは config/locales へ追加。複数形化不要」に確定する。**モデル名・カラム名の例外規定も撤廃**する
  （全キーがローカル化されたので例外は不要）。
- copy_tuner 系スキル（`.claude/skills/` 配下の copy_tuner 操作スキル）を無効化または削除する。
- `README.md` の copy_tuner リンク・補助ドキュメント（「copy_tuner サーバで i18n 管理」記述を持つコマンド定義等）
  を修正する。
- copy-tuner MCP server の接続設定（`.mcp.json` 等）を除去する。

### 8. 最終検証

`references/verification-final.md` の手順で、痕跡が残っていないか・gem が外れているか・テストが外部 API
接続なしで通るか・未訳が出ないかを確認する。

## 完了の目安

- `git grep -i 'copy.tuner\|copytuner\|CopyTunerClient'`（vendor/tmp 除外）でアプリ側のヒットが無い。
- 全翻訳キーが `config/locales` で解決し、`translation missing` が出ない。
- テスト・Linter が通り、外部 API 接続なしで CI が完結する。
- 方針ドキュメントが config/locales 管理に最終化され、「移行中」やモデル名・カラム名の例外記述が残っていない。

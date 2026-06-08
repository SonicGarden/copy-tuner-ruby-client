# export と prefix サブツリーの抜き出し・YAML 分割

SKILL.md 手順 3・6 の詳細。

## rake copy_tuner:export の挙動

```bash
bundle exec rake copy_tuner:export[出力先パス]
```

- 引数を省略するとデフォルトで `config/locales/copy_tuner.yml` に書き出す。**段階移行では全件を一時ファイルへ
  出して俯瞰・抜き出しの元データにする**ため、`tmp/copy_tuner_all.yml` のような捨て場を明示指定する。
- 内部で `CopyTunerClient.cache.sync` を呼び、copy_tuner サーバから最新 blurb を取得してから書き出す。
  ローカルのポーラーキャッシュ任せにせず必ずこのタスクを使うのは、同期済み・全件であることを保証するため。
- blurb が一件もキャッシュできないと `No blurbs have been cached.` で失敗する。その場合は API key
  （credentials または `COPYTUNER_API_KEY`）と project_id の設定、ネットワーク到達性を確認する。
- 出力は単一の YAML で、トップに copy_tuner に登録された全ロケールのキー（`ja:`、複数運用なら `en:` 等も）が
  並び、その下に blurb のドット区切りキーがネストした Hash に展開された形になる。

## 出力 YAML の構造（典型）

トップレベルロケール（複数運用なら `ja:` / `en:` …）の下に、Rails の i18n 慣習どおりのセクションがフラットに
並ぶ。実際のプロジェクトではおおむね次のようなセクションが現れる:

```
ja:   # 複数ロケール運用なら en: 等も同じ構造で並ぶ
  activemodel:
    attributes:        # Form オブジェクトの属性名
  activerecord:
    attributes:        # モデル属性名（CSV ヘッダ・フォームラベル等）
    enums:             # enum 値の表示名
    models:            # モデルの human 名
    errors:            # カスタムバリデーションメッセージ
  views:               # 画面テキスト・ヘルプ文
  text:                # 汎用ボタンテキスト等
  helpers:             # submit ラベル等
  date: / time: / datetime: / number:   # Rails 標準フォーマット
  devise:              # gem 由来
  good_job: / ice_cube: / restrict_dependent_destroy:  # gem 由来
```

このトップセクションの単位が、SKILL.md 手順 4 の「対象 prefix」の基本粒度になる。

## 対象 prefix のサブツリーだけを抜き出す（スクリプトが担う）

段階移行では**今回の prefix のサブツリーだけ**を config/locales へ持ち込む（全件は持ち込まない）。この抽出・
配置・検証・削除は SKILL.md 手順 6 の `scripts/migrate_prefix.rb` が決定論的に行う。スクリプトの内部処理:

- 全件 export YAML（`tmp/copy_tuner_all.yml`）から対象 prefix（例 `views`）以下を、対象 locale（`--locales`／
  既定は `I18n.available_locales`）すべてのロケールキー（`ja:`、複数運用なら `en:` 等）を保ったまま切り出す。
  他の prefix（まだ移行しないもの）は持ち込まない（引き続き CopyTuner から引かれる）。
- 抜き出した leaf キーが手順 7 で `local_first_key_regexp` に足す prefix（`--regexp`／既定 `/\A<prefix>\./`）と
  **一致しているか**を静的ガードで自動確認する（regexp がマッチするのにローカルに無い＝未訳を防ぐ）。

## 分割の方針（配置先ファイル）

スクリプトの `--out` は、**オリジナル（`0000_original_*.yml`）より後にロードされる採番**（`0010_` 以降）の
ファイルにする。SKILL.md 手順 2-1 で既存 locales を `0000_original_` に固定済みなので、移行分を後ろに置けば
Rails i18n の後勝ちで**重複キーは自動的に export 側が勝つ**（手作業マージ不要）。

分割の目安（1 prefix ＝ 1 ファイルにすると、どの prefix を移行済みか／regexp と config/locales の対応が追いやすい）:

| ファイル例 | 入れるセクション |
|---|---|
| `0000_original_*.yml`（既存・先頭固定） | 未移行 prefix の残り（移行のたびに該当 prefix を削除していく） |
| `0020_activerecord.yml` | `activerecord.attributes` / `activerecord.models` / `activerecord.errors` |
| `0030_activemodel.yml` | `activemodel.attributes` / `activemodel.errors` |
| `0040_views.yml` | `views` / `text` |
| `0050_gems.yml` | good_job / ice_cube / restrict_dependent_destroy / devise 等 |

> 採番は目安。ポイントは **`0000_original_`（先頭）＜ 移行分 `0010_` 以降** のロード順を保つこと。
> これにより重複キーは **export 側を正とする**が構造的に保証される（次節）。非表現値（date/number の配列・
> シンボル・数値）は別ファイルに隔離せず、スクリプトが移行分（`0010_` 以降）の中へ取り込む（後述）。

## 既存 locales との重複は後勝ちで解決し、オリジナルから削除する

抜き出したサブツリーに、すでにオリジナル（`0000_original_*.yml`）に存在するキー（Rails 標準・devise・
アプリ固有 enum 等）が含まれることがある。**手作業でのマージはしない。** スクリプトとロード順で解決する:

- スクリプトは `orig_sub.deep_merge(exp_sub)`（オリジナル抽出分をベースに export で上書き）で `--out` を作る。
  葉が両方にあれば export が勝ち、**「export を正とする」を満たす**。さらに `0000_` 先頭・`0010_` 後ロードの
  Rails 後勝ちでも二重に保証される。
- 配置・移行漏れ検証を通った後、スクリプトが**移行した prefix のサブツリーをオリジナルから削除する**
  （空親も刈る）。残存内容が「未移行 prefix」を表す進捗マーカーになり、重複定義も消えて YAML がクリーンに保たれる。

## copy_tuner で表現できない値（非表現値）の引き継ぎ

copy_tuner は flat な文字列 blurb しか持てないため、次の値は export に出てこない／文字列化されて壊れる:

- **配列**: `date.abbr_day_names` / `day_names` / `month_names` / `abbr_month_names` 等
- **シンボル配列**: `date.order`（`:year` / `:month` / `:day`）等
- **数値・真偽値**: `number.*.precision`（整数）/ `significant` / `strip_insignificant_zeros`（真偽値）等
- **ハッシュ値**: 上記のように構造を持つ Rails 標準フォーマット群

これらは基本 export に出てこず**オリジナルにしか無い**が、**壊れた形（文字列化された値、過去に管理画面で手動
登録された値、将来の gem の型変換結果）で export に出てくる可能性**もある。スクリプトは 3 段の deep merge で
これを守る:

1. `orig_sub` をベースに
2. export を上書き（String blurb は export 勝ち）
3. 最後に**オリジナル由来の非表現値（非 String leaf）だけ**を再適用（`select_non_blurb(orig_sub)`）

これにより、export に壊れた非表現値が出ても **3 段目で orig の正値が置換勝ちする**（deep merge は配列・スカラを
右辺で置換するので、最後に来た orig 値が export の壊れた値を上書きする）。**非表現値は orig 値で `--out` に残る**。
別ファイル（旧 `0005_rails_non_blurb.yml`）への隔離は**不要**。

> 原則の住み分け: 「重複キーは export を正とする」は **copy_tuner で表現可能な String blurb にのみ**成り立つ。
> 非表現値はそもそも copy_tuner に正しく存在しえない（gem の `store_item` が `respond_to?(:to_str)` で非文字列を
> 弾く）ので、orig を勝たせるのが常に正しい。同じ `date` prefix 内で `date.formats`（文字列・export 勝ち）と
> `date.order`（シンボル配列・orig 勝ち）が排他的に住み分く。2 原則は衝突しない。

> なぜ隔離が要らないか: 隔離方式は「export 由来ファイルに非表現値を混ぜると壊れる」ことを避ける狙いだったが、
> スクリプトは 3 段マージ（orig ベース → export 上書き → 非表現値の再適用）で非表現値の喪失・上書きを構造的に
> 防ぎ、`--out` 単一ファイルに収める。削除も「漏れゼロを実 lookup で確認してから」スクリプトが行うので、
> 非表現値を巻き添えで失う事故（prefix を丸ごと消す手作業ミス）も起きない。

> 参考: gem 側の型変換は [copy-tuner-ruby-client#104](https://github.com/SonicGarden/copy-tuner-ruby-client/pull/104)
> で `*.precision` → integer、`*.significant` → boolean 等が補われる。ただし**配列・シンボルは対象外**。いずれに
> せよ 3 段目の非表現値再適用で orig 値が勝つため、coerce された値・壊れた値どちらが export に出ても安全。

## html_escape 由来の値の扱い

copy_tuner を `html_escape = true` で運用していた場合、export された値には HTML エスケープ前提の文字列や
`*_html` キー慣習が含まれることがある。Rails 標準の i18n も `*_html` サフィックスのキーは自動で
`html_safe` 扱いにするため、基本はそのまま移せる。ただし SKILL.md 手順 5 の `detect_html_incompatible_keys`
で警告が出たキーは、移行前に copy_tuner 側で整理しておくこと（そのまま持ち込むと表示が壊れる）。

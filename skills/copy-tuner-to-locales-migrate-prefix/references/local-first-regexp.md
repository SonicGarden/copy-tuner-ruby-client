# local_first_key_regexp の使い方

SKILL.md 手順 7 の詳細。prefix 単位移行の核心となる gem オプション。

## 何をするオプションか

[copy-tuner-ruby-client #110](https://github.com/SonicGarden/copy-tuner-ruby-client/pull/110) で
`Configuration#local_first_key_regexp` が追加された。`I18nBackend#lookup` は次のように動く:

```ruby
# locale を除いたキー（例: "views.foo.bar"）が regexp にマッチしたら…
if local_first_key?(key_without_locale)
  return super   # ← I18n::Backend::Simple に委譲。CopyTuner キャッシュもアップロードキューも触らない
end
# マッチしなければ従来どおり CopyTuner キャッシュ優先 → 無ければ super
```

判定は `key_without_locale.to_s.match?(local_first_key_regexp)` の単純マッチ。

## 完全分離の意味

マッチキーは **CopyTuner を一切参照しない**。つまり:

- ローカル YAML に値があればそれを返す。
- ローカル YAML に**無ければ即 `nil`（未訳）**。CopyTuner へフォールバックしない。
- 空キーのアップロードキュー投入もしない（`Cache#[]=` の単一関門で抑止）。
- CopyRay のオーバーレイマーカー（`<!--COPYRAY key-->`）も注入されない（編集できないキーを編集可能と誤認
  させないため）。

この「無ければ未訳」の挙動こそが、**移行漏れ（ローカルへ書き忘れたキー）を未訳として顕在化させる**仕組み。
だから移行のたびに `translation missing` チェック（SKILL.md 手順 8）が効く。

## regexp は単一・配列非対応

`local_first_key_regexp` は単一の `Regexp` を取る（`attr_accessor`、デフォルト `nil`）。**配列は渡せない**。
複数 prefix を移行済みにするには **1 本の正規表現に積み上げる**。`Regexp.union` を使うのが安全:

```ruby
config.local_first_key_regexp = Regexp.union(
  /\Adevise\./,
  /\Aice_cube\./,
  /\Arestrict_dependent_destroy\./,
  /\Aviews\./,
)
# => /(?-mix:\Adevise\.)|(?-mix:\Aice_cube\.)|.../ 相当
```

`Regexp.union` はメタ文字のエスケープを自動でやり、要素を OR でつなぐので、prefix を 1 行ずつ足すだけで済む。
手書きの `/\A(devise|ice_cube|...)\./` でも等価だが、union のほうが追記時のミスが少ない。

## `\A` アンカー必須

各 prefix は **`\A` で先頭アンカー**する。キーは locale 除去後なので `\A` 起点でよい。

- `\A` 無しの `/views\./` は `reviews.foo` の `views.` 部分にもマッチしてしまう（部分マッチ事故）。
- `\Aviews\.` なら `views.` で始まるキーだけにマッチする。
- `views` 配下を更に刻むなら `\Aviews\.users\.` のように 2 階層目までアンカーできる。

ドット `.` は正規表現のメタ文字なので、prefix 区切りのドットは `\.` とエスケープする
（`/\Aviews\./`。`Regexp.union` に文字列を渡す場合は自動エスケープされるが、Regexp リテラルを渡すときは自分で
書く）。

## 旧 exclude_key_regexp について

かつて存在した `exclude_key_regexp` オプションは v2 で削除済み。`local_first_key_regexp` を使うこと
（対象は locale を**除いた**キー `views.foo`、lookup 時に作用しローカル YAML を優先＝完全分離）。
既存 initializer に `exclude_key_regexp` の設定が残っている場合は削除する。

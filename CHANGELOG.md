## Unreleased

- **【後方互換性に影響】** `config.exclude_key_regexp` を削除しました。後継の `config.local_first_key_regexp`
  を使ってください。両者は対象キーの形式が異なります（`exclude_key_regexp` は locale 付き `ja.views.foo`、
  `local_first_key_regexp` は locale を除いた `views.foo`）。正規表現から locale プレフィックスを外して
  移行してください。挙動も異なり、`local_first_key_regexp` は lookup 時に CopyTuner キャッシュをスキップして
  ローカル YAML を優先します（完全分離）。
- **【後方互換性に影響】** `config.project_id` を必須にしました。未設定のまま `configure`（`apply`）すると
  `ArgumentError: project_id is required` で失敗します。これまで `project_id` 未設定時は `api_key` へ
  フォールバックして deprecation 警告を出していましたが、このフォールバックは削除しました。initializer に
  `config.project_id = <プロジェクト ID>` を設定してください。
- Copyray オーバーレイのマーカー方式を刷新。訳文への HTML コメント `<!--COPYRAY key-->` 注入をやめ、
  可視トークン `⟦CT:key⟧` を埋め込んだうえで `CopyrayMiddleware` が `data-copyray-key` 属性に変換し、
  トークンを HTML から完全に除去するようになりました。最終配信 HTML にコメント・トークンは残りません。
- **【後方互換性に影響】** `config.html_escape` 設定を削除しました。HTML の安全性判定は i18n 標準
  （`.html` / `_html` で終わるキーのみ html_safe）に統一され、この設定は参照されなくなっていました（no-op）。
  no-op だったため動作には影響しませんが、`config.html_escape = ...` を設定している initializer は
  `NoMethodError` になるため、その行を削除してください。`html_escape = false`（全訳文を html_safe 扱いに
  する旧互換挙動）に依存していたアプリは、`.html` / `_html` キー命名へ移行してください。
- Copyray オーバーレイは平文・html_safe（`.html` / `_html` キー）どちらの訳文もハイライト対象です。マーカートークンの
  区切り記号は HTML 特殊文字ではないため、平文訳文が ActionView でエスケープされてもトークンは無傷で残り、
  `data-copyray-key` 属性へ正しく変換されます。`<head>` 内（title/meta）はトークンを除去するのみでオーバーレイ
  非対象ですが、従来どおりリスト導線（CopyTuner バー）から編集できます。
- **【後方互換性に影響】** `tt` ヘルパーを削除しました。マーカー方式の刷新で `t`（`translate`）が安全にマーカー
  注入できるようになり、`tt` の存在理由は失われました。`tt` の呼び出しは `t` へ置き換えてください。`tt` を使い続けたい
  アプリは、ビューヘルパーで `t` に委譲するだけの `tt` を自前で定義してください（gem 撤去後は `t` と実質同義）。

## 0.16.1

- Support for i18n@1.13.0
- キーの相対パス指定とdefaultオプションを組み合わせた場合の不具合修正

## 0.16.0

- Railsエンジン内のviewではオリジナルのtヘルパが呼ばれるように修正

## 0.15.1

- tヘルパーにdefault引数が渡された場合に初期値として登録されない問題を修正

## 0.15.0

- Drop support for ruby 2.7

## 0.14.1

- Fix super call in define_method

## 0.14.0

- Add Support for good_job
- Drop Support for Resque

## 0.13.5

- Rename assets

## 0.13.4

- Fix csp nonce

## 0.13.3

- Add `media="all"` attribute to stylesheet link tag

## 0.13.2

- Add `crossorigin="anonymous"` attribute to script tag

## 0.13.1

- Add `type="module"` attribute to script tag

## 0.13.0

- Drop support for ruby 2.6

## 0.12.0

- Add `config.ignored_keys` and `config.ignored_key_handler`

## 0.11.0

- Remove deprecated rescue_format option
- Fix ruby@2.7 keyword warning

## 0.10.0

- Add copy_tuner:detect_html_incompatible_keys task

## 0.9.0

- Do not upload invalid type keys

## 0.8.1

- Fix bug in `CopyrayMiddleware`

## 0.8.0

- Change the default value of config.upload_disabled_environments

## 0.7.0

- Add config.upload_disabled_environments

## 0.6.2

- Add arguments to export task

## 0.6.1

- Fix ruby@2.7 keyword warning

## 0.6.0

- Drop support for ruby 2.4
- Drop support for rails 5.1

## 0.5.2

- Do not upload invalid keys

## 0.5.1

- Do not upload downloaded keys

## 0.5.0

- Drop support for ruby 2.3
- Add tt helper
- Add copy_tuner:detect_conflict_keys task
- Do not re-upload empty keys
- Fix dual loading tasks
- Remove config.copyray_js_injection_regexp_for_debug
- Remove config.copyray_js_injection_regexp_for_precompiled
- Download translation when initialization

## 0.4.11

- changes
  - Fix hide toggle button on mobile device.

## 0.4.10

- changes
  - Hide copyray bar on all media.

## 0.4.9

- changes
  - Smaller toggle button.
  - Hide toggle button on mobile device.

## 0.4.8

- changes
  - Support passenger 5.3.x

## 0.4.7

- changes
  - Compatibile with bullet gem (rewrap response with ActionDispatch::Response::RackBody)

## 0.4.6

- changes
  - Performance imporovement (sync with server asynchronously)
  - Add config.middleware_position

## 0.4.5

- changes
  - Fix deprecated css.

## 0.4.4

- bug fix
  - Don't upload resolved default values.

## 0.4.3

- bug fix
  - Start poller thread regardless of puma mode. #39

## 0.4.2

- changes
  - span tag is no longer added to translation text.

## 0.4.1

- bug fixes

  - js injection failed if jquery is not used. #33
  - Fix some js error. #34
  - Wrong key is displayed if scoped option is used. #35

- deprecation
  - config.copyray_js_injection_regexp_for_debug is no longer needed.
  - config.copyray_js_injection_regexp_for_precompiled is no longer needed.

## 0.4.0

- Remove jQuery dependency.

## 0.3.5

- Support Rails 5.1

## 0.3.4

- Use Logger to /dev/null as default when rails console

## 0.3.3

- Add config.locales. (#24)
- Fix initialization order bug. (#25)

## 0.3.2

- Support I18n.t :scope option.
- Update copyray_js_injection_regexp_for_debug.

## 0.3.1

- Add search box to copyray bar.
- Add disable_copyray_comment_injection to configuration.

## 0.3.0

- Use https as default.
- Download blurbs from S3.
- Add toolbar.
- "Translations in this page" menu.

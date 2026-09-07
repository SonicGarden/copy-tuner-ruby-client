# poller がどのプロセスで起動するか

`Poller` はバックグラウンドスレッドで CopyTuner サーバと同期する。**リクエストを処理するプロセスで
このスレッドが動いていないと翻訳が更新されない**が、動いていなくてもエラーにはならず、翻訳が古いまま
になるだけなので気づきにくい。アプリケーションサーバの起動方法とモードによって「どのプロセスがアプリを
ロードするか」が変わるため、ここに実測結果を残す。

Puma 以外（Unicorn / Passenger / delayed_job / good_job）については `ProcessGuard` のフック登録
メソッドを参照。

## 前提: アプリをロードしたプロセスで initializer が走る

`CopyTunerClient.configure`（＝ `Configuration#apply` ＝ `ProcessGuard#start`）は、Rails の
initializer として **アプリをロードしたプロセスで 1 回だけ**走る。したがって「どのプロセスがアプリを
ロードするか」が起点になる。

## 実測結果

検証環境: puma 8.0.2 / Rails 8.1.3.1 / Ruby 4.0.2（2026-09-03 実測）

| 起動方法 | モード | アプリをロードするプロセス | poller の起動経路 | master に poller |
| --- | --- | --- | --- | --- |
| `rails server` | single | そのプロセス | 非 spawner 経路（`start_polling`） | （単一プロセス） |
| `rails server` | cluster（preload の有無を問わず） | **master のみ** | master で `start_polling` → `ForkHook` が fork 後に worker で張り直す | 立つ |
| `puma -C` | single | そのプロセス（`Runner#load_and_bind`） | `Puma::Runner#start_server` への prepend | （単一プロセス） |
| `puma -C` | cluster + preload | master のみ | 各 worker の `start_server` で prepend したフックが発火 | 立たない |
| `puma -C` | cluster + preload なし | **各 worker** | `$0` の `'cluster worker'` 判定による分岐 | 立たない（master はアプリをロードしない） |

### 判定に使っている値

`ProcessGuard#puma_spawner?` は `defined?(Puma::Runner) && $PROGRAM_NAME.include?('puma')` で判定する。
実測値は次のとおり。

| 起動方法 | `$PROGRAM_NAME` | `defined?(Puma)` | `defined?(Puma::Runner)` | `puma_spawner?` |
| --- | --- | --- | --- | --- |
| `rails server` | `"bin/rails"` | yes | **no** | false |
| `puma -C`（master / single） | `".../bin/puma"` | yes | yes | true |
| `puma -C`（preload なしの worker） | `"puma: cluster worker 0: <master pid> [app]"` | yes | yes | true |

`$PROGRAM_NAME` が master と worker で違うのは Puma 側の実装差による。master は
`launcher.rb` の `Process.setproctitle`（`$0` を変えない）、worker は `cluster/worker.rb` の
`$0 = title`（変える）を使っている。

## 各行の背景

### `rails server` は preload 設定に関係なく master でアプリをロードする

Rails は Puma を起動する**前に** Rack アプリを組み立てて（`Rails::Server#log_to_stdout` →
`wrapped_app`）、オブジェクトとして Puma に渡す。そのため `preload_app!` を明示的に切っても worker が
アプリをロードし直すことはなく、必ず master でロードされる。

この構成では `Puma::Runner` が initializer の時点でまだ未定義なので `puma_spawner?` は false になり、
master で poller が起動する。fork 後の worker には `ForkHook`（`Process._fork` に prepend）が
引き継ぐ。master にも poller が 1 本残るが、`puma_spawner?` を無理に真にしようとすると起動方法ごとの
判定を増やすことになるため、余分な 1 本を許容している。

### Puma 8 は `workers > 1` のとき preload が既定で有効

`Puma::Configuration#set_conditional_default_options` が `preload_app` の既定値を
`!prune_bundler && workers > 1 && Puma.forkable?` で決めている。非 preload を試すには
`preload_app!(false)` を明示する必要がある。

### 非 preload では `start_server` の中でアプリがロードされる

`Runner#start_server` は `Puma::Server.new(app, ...)` を呼び、`Runner#app` が
`@app ||= @config.app` で遅延ロードする。つまり非 preload の worker では、initializer が走る時点で
既に `start_server` が実行中であり、**そこで `Puma::Runner` に prepend しても間に合わない**。

このため `$0` の `'cluster worker'` 判定は最適化ではなく、この構成で poller を起動する唯一の経路になっている。

## 表のとおりにならない例外

上の表は「poller のスレッドが起動する経路」であって、起動した poller が動き続けることまでは
保証しない。`Poller` はスレッドの生死とは別にライフサイクルの意図を持っており、次の場合は
表の経路を通っても poller が居なくなる。

- **`InvalidApiKey`** — API キーが不正だと `poll` が自ら終了し、以後は fork をまたいでも張り直さない
  （張り直しても同じ理由で死ぬだけなので）。ログに `Invalid API key` が出る
- **起動時に CopyTuner サーバへ到達できない** — `Configuration#apply` の `cache.download` が
  `ConnectionError` を再送出するため、そもそもプロセスが起動に失敗する。Puma の worker では
  `! Unable to start worker` になる

再検証の際は、まずこの 2 つに当たっていないかをログで確かめる。

## 再検証のしかた

Puma や Rails を上げたときにこの表が変わっていないか確かめるには、次の観測点を見るのが早い。

1. 最小の Rails アプリを用意し、`config/initializers` で `Process.pid` / `Process.ppid` /
   `$PROGRAM_NAME` / `defined?(Puma::Runner)` を出力する。これで**どのプロセスがアプリをロードしたか**が分かる
2. 任意のエンドポイントで `CopyTunerClient.poller` の `@thread` を覗き、`alive?` を返す。
   fork 後の worker が親から継承した dead な Thread を持っていると、ここが `false` になる
3. 翻訳を返すだけの偽 CopyTuner サーバを立て（`draft_blurbs.json` を返し、`draft_blurbs` /
   `deploys` の POST を受ける）、`polling_delay` を数秒にする。起動後にサーバ側の翻訳を書き換え、
   worker が拾うかどうかで実際の同期を確認する
4. 上の表の 5 構成（`rails server` / `puma -C` × single / cluster+preload / cluster+非 preload）で回す

`ProcessGuard` のログ（`Register Puma fork hook` / `Puma would be clustered mode without preload_app` /
`start poller thread`）をプロセス ID 付きで集計すると、どの経路を通ったかが分かる。

## 関連

- `CopyTunerClient::ForkHook` — fork をまたいで poller を引き継ぐ。判定が外れて master で poller が
  起動してしまった場合の安全網でもある
- `CopyTunerClient::Poller` — スレッドの生死とは別に `@running`（ポーリングを継続する意図）と
  `@aborted`（張り直しても同じ理由で死ぬ終わり方をしたか）を持つ。`ForkHook` が fork 後に張り直すか
  どうかは `Poller#stop` の戻り値、すなわちこの意図で決まる（スレッドが生きているかではない）
- [Ruby における fork と Thread の挙動の調査](https://gist.github.com/shunichi/c236b6a85a46a16c60262047ca299608)

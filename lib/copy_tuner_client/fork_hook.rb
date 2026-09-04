module CopyTunerClient
  # fork をまたいで poller スレッドを引き継ぐためのフック。
  # Process._fork に prepend し、fork の直前に poller を協調的に停止して、
  # fork のあと親子それぞれで張り直す。
  module ForkHook
    # Module#prepend は同じモジュールを二重に挿さないので、呼び出し側で登録済みかを見なくてよい
    def self.install
      ::Process.singleton_class.prepend(self)
    end

    def _fork
      # fork はアプリの任意のタイミングで起きる。Process._fork への prepend は外せないので、
      # configure 前や configuration 差し替え中に NoMethodError でアプリの fork を
      # 壊さないよう nil を許容する
      poller = CopyTunerClient.configuration&.poller
      # スレッドは子プロセスに引き継がれない。fork 後に子へ残る Thread オブジェクトの見え方
      # （alive? / join の結果）はドキュメント化されていない CRuby の実装依存なので、
      # そこに依存した後始末はせず、fork 前に協調的に停止しておく。
      # ここは rescue しない。停止の失敗を握り潰すと、動いている poller ごと fork することになり
      # このフックの目的そのものを裏切る
      restart = poller ? poller.stop : false

      begin
        super
      ensure
        # ensure は親（super の戻り値 = 子の pid）と子（同 0）の両方を通り、super が失敗した
        # ときも親で復元する。「fork 前に動いていたプロセスは fork 後も動いている」状態を保つ。
        # 子でも張り直すのは、Puma の fork_worker のように worker が worker を fork する
        # 構成でもサーバ固有のフックに頼らず poller を立てるため
        ForkHook.restart_poller(poller) if restart
      end
    end

    # Process.singleton_class に prepend されるため、インスタンスメソッドとして定義すると
    # Process 自身にメソッドが生えてしまう。フックの補助はモジュール側の特異メソッドに置く
    #
    # fork 後に例外を漏らすと「子プロセスは生成済みなのに親の fork が例外を投げる」状態になり、
    # 呼び出し側が子の pid を受け取れなくなる。起動の失敗はログに落として fork は成立させる
    def self.restart_poller(poller)
      poller.start
    rescue StandardError => e
      CopyTunerClient.configuration&.logger&.error(
        "CopyTuner: fork 後の poller 起動に失敗しました: #{e.class}: #{e.message}"
      )
    end
  end
end

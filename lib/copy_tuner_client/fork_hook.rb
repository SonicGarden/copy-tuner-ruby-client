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
      poller = CopyTunerClient.poller
      # スレッドは子プロセスに引き継がれない。fork 後に子へ残る Thread オブジェクトの見え方
      # （alive? / join の結果）はドキュメント化されていない CRuby の実装依存なので、
      # そこに依存した後始末はせず、fork 前に協調的に停止しておく
      restart = poller ? poller.stop : false

      begin
        super
      ensure
        # ensure は親（super の戻り値 = 子の pid）と子（同 0）の両方を通る。
        # 「fork 前に動いていたプロセスは fork 後も動いている」状態を双方で復元する。
        # 子でも張り直すのは、Puma の fork_worker のように worker が worker を fork する
        # 構成でもサーバ固有のフックに頼らず poller を立てるため
        poller.start if restart
      end
    end
  end
end
